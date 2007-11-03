# restfully_yours
#
# Copyright (c) 2007 Assaf Arkin, http://labnotes.org
# In the public domain.


# Allows client-side caching and conditional updates using the Last-Modified and ETag headers.
#
# A conditional GET uses the If-Modified-Since/If-None-Match headers to determine whether the entity
# was modified since the last response, returning a new response only if there are relevant modifications.
# The #if_modified method compares these headers against a list of arguments.  If modified, it yields to
# the block to render a new response, and calls #modified to set new headers.  If not modified, it sends
# back 304 (Not Modified) response.
#
# A conditional PUT uses the If-Unmodified-Since/If-Match headers to determine whether the entity remains
# unmodified since the last response, to prevent updates from stale data.  The #if_unmodified method
# compares these headers against a list of arguments.  If unmodified, it yields to the block to perform
# the update and render a new response, and calls #modified to set new headers.  If not modified, it sends
# back 412 (Precondition Failed) response.
#
# For example:
#   # Render only if modified since last GET/PUT.
#   def show()
#     @item = Item.find(params[:id])
#     if_modified @item do
#       render :action=>"item"
#     end
#   end
#
#   # Update only if not modified since last GET/PUT.
#   def update()
#     @item = Item.find(params[:id])
#     if_unmodified @item do
#       @item.update_from params
#       render :action=>"item"
#     end
#   end
#
# The Last-Modified value is calculated from the list of arguments by calling updated_at/updated_on on each
# of the argument and returning the latest modification dates.  If you are using ActiveRecords with timestamps,
# this will work as you expect it to.
#
# The ETag value is calculated from the list of arguments by calling etag on each of the arguments and returning
# a hash from the combined ETag.  ETags are used only if all arguments respond to the method etag, and a special
# value is used for the empty list.  Order is important, so different orders (e.g. sorted lists) return different ETags.
#
# ETags are more expensive to calculate, but provide better time resolution than Last-Modified.  In addition,
# #if_modified and #if_unmodified respond to multiple ETags in the If-Match/If-None-Match headers and to requests
# with '*', checking against an existing entity.
#
# The methods #if_modified, #if_unmodified and #modified accept any number of arguments and flatten arrays.
# You can use that with actions that render a collection of records, or depend on several objects, for example,
# shopping cart and items contained there.  You can also use it with no arguments or nil, to handle requests that
# do not have a matching entity.
#
# When used, this behavior overrides the use of ETag to cache the rendered response.
module IfModified

  module ActionControllerMethods

  protected

    # Checks for modification before returning response.  Checks the arguments against last modified and
    # etag headers sent to the client in a previous request.  If modified, yields to the block to render
    # the response, and calls modified afterwards.  Otherwise, sends back the 304 (Not Modified) status.
    def if_modified(*args)
      args = args.flatten.compact
      if conditional(args)
        yield
        modified args
        true
      else
        etag = etag_from(args)
        response.headers['ETag'] = etag ? %{"#{etag}"} : ''
        response.headers.delete 'Cache-Control'
        return head(:not_modified)
      end
    end

    # Checks for modification before returning the resource.  Checks the arguments against last modified and
    # etag headers send to the client in a previous request.  If not modified, yields to the block to render
    # the response, and calls modified afterwards.  Otherwise, sends back the 412 (Precondition Failed) status.
    def if_unmodified(*args)
      args = args.flatten.compact
      if conditional(args)
        yield
        modified args
        true
      else
        return head(:precondition_failed)
      end
    end

    # Sets the ETag header.
    def etag=(etag)
      response.headers['ETag'] = etag ? %{"#{etag}"} : ''
    end

    # Sets the Last-Modified header.
    def last_modified=(time)
      if time
        response.headers['Last-Modified'] = time.httpdate
      else
        response.headers.delete('Last-Modified')
      end
    end

    # Sends modification headers for later use with if_modified.  You can call this method with any number
    # of arguments, make sure to use the same arguments in if_modified (e.g. a database record or ordered
    # array of records).
    #
    # Determines last modified time by calling update_on or update_at on each of the objects and returning
    # the highest value.  Determines etag by calling etag method on each of the objects and returning a
    # combined etag.  This will also work with an empty argument list, and the order of arguments does matter.
    #
    # Set the second argument to true (default) to make sure the response is not cached on behalf of
    # multiple clients, for example, if the response is specific to a user.  Set the second argument to
    # false if it can be cached on behalf of multiple clients.
    def modified(*args)
      # TODO: Need more status codes
      return unless response.headers['Status'].nil? || response.headers['Status'] =~ /^20[01]/
      args = args.flatten.compact
      last_modified = last_modified_from(args)
      etag = etag_from(args)
      response.headers['Last-Modified'] ||= last_modified.httpdate if last_modified
      response.headers['ETag'] ||= etag ? %{"#{etag}"} : ''
      caching = (response.headers['Cache-Control'] || '').split(/,\s*/)
      caching.delete "no-cache"
      caching << "private" unless caching.include?("public")
      caching << "max-age=0" unless caching.any? { |control| control =~ /^max-age=/ }
      caching << "must-revalidate"
      response.headers['Cache-Control'] = caching.uniq.join(', ')
    end

    # Decides whether to execute a conditional request based on list of arguments and relevant HTTP headers.
    # Returns true if the request MUST execute, false otherwise.
    #
    # Matches the headers If-Modified-Since and If-Unmodified-Since against the last modification of the arguments.
    # Matches the headers If-Match and If-None-Match agains the ETag calculated from the arguments.
    #
    # Arguments can be a hash with the values :etag and :last_modified, or an array of objects for calculating
    # the ETag and Last-Modified values.
    def conditional(args)
      if Hash === args
        etag, last_modified = args.values_at(:etag, :last_modified)
      else
        objects = Array(args).flatten.compact
      end

      modified_since = Time.parse(request.headers['HTTP_IF_MODIFIED_SINCE'].to_s) rescue nil if
        request.headers['HTTP_IF_MODIFIED_SINCE']
      unmodified_since = Time.parse(request.headers['HTTP_IF_UNMODIFIED_SINCE'].to_s) rescue nil unless
        request.headers['HTTP_IF_UNMODIFIED_SINCE'].blank?
      match = request.headers['HTTP_IF_MATCH'].to_s.split(/,\s*/).map { |tag| tag[/^("?)(.*)\1$/, 2] }.reject(&:empty?)
      none_match = request.headers['HTTP_IF_NONE_MATCH'].to_s.split(/,\s*/).map { |tag| tag[/^("?)(.*)\1/, 2] }.reject(&:empty?)

      if modified_since || unmodified_since
        last_modified ||= last_modified_from(objects || [])
        # Perform if modified-since/unmodified-since conditional fails.
        return true if (modified_since && last_modified.to_i > modified_since.to_i) ||
          (unmodified_since && last_modified.to_i < unmodified_since.to_i)
        # Without match/none-match, we have enough info to fail (or not) the condition.
        return (modified_since && modified_since.to_i != last_modified.to_i) ||
          (unmodified_since && unmodified_since.to_i == last_modified.to_i) if match.empty? && none_match.empty?
      end
      # Conditional fails if '*' matches anything or does not match nothing.
      if objects
        return true if (none_match.delete('*') && !objects.empty?) || (match.delete('*') && objects.empty?)
      else
        return !etag if none_match.delete('*')
        return !!tag if match.delete('*')
      end
      # Always perform without conditional.
      return true if match.empty? && none_match.empty?
      etag ||= etag_from(objects)
      return (!match.empty? && match.include?(etag)) || (!none_match.empty? && !none_match.include?(etag))
    end

  private

    # Returns last modified from arguments. Determines motification by calling update_on or update_at on each
    # of these objects and taking the last value.
    def last_modified_from(args)
      args.map { |obj| (obj.respond_to?(:updated_on) && obj.updated_on) ||
        (obj.respond_to?(:updated_at) && obj.updated_at) || nil }.compact.max # || Time.at(0)
    end

    # Returns etag from arguments.  Determines etag by calling etag on each object and then combining them
    # into a hash.  Returns nil if cannot generate etag from all the arguments.
    def etag_from(args)
      return nil unless args.all? { |obj| obj.respond_to?(:etag) }
      values = [request.format.to_s] + args.map { |obj| obj.etag }
      Digest::MD5.hexdigest values.join("; ")
    end

  end


  module ActiveRecordMethods

    # Calculates an ETag for this object.
    #
    # Uses the record attributes to calculate an ETag using an MD5 hash, so two ETags match only if both
    # records have the same value for all their attributes.  For optimistic locking, calculates the ETag
    # using only the record identifier and lock_version.  Includes loaded associations for both.
    def etag()
      attrs_for_etag = (locking_enabled? ? [ :id, self.class.locking_column ] : attributes.keys).inject({}) do | attrs,name|
        attrs.update name => send(name)
      end

      self.class.reflect_on_all_associations.map(&:name).each do |name|
        next unless (association = send(name)).loaded?
        attrs_for_etag.update name => Array(association).map(&:etag)
      end

      Digest::MD5.hexdigest(attrs_for_etag.to_query)
    end

  end

end

ActionController::Base.send :include, IfModified::ActionControllerMethods
ActiveRecord::Base.send :include, IfModified::ActiveRecordMethods
