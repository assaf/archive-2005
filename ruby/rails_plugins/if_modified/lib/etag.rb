module ActiveRecord #:nodoc:
  module ETag

    # Returns an etag value for this record, suitable for use as ETag header.  Calculates the ETag
    # from the value of all (including protected) attributes and returns a digest.  When using
    # optimistic locking, calculates the ETag from the ID and locking column alone.  Since the
    # record ID is required, returns nil for unsaved records.
    def etag
      return if new_record?
      columns = locking_enabled? ? [:id, self.class.locking_column] : self.class.column_names
      attributes = columns.inject({}) { |hash, name| hash.update(name=>send(name).to_s) }.to_query
      MD5.hexdigest("#{self.class.name}:#{attributes}")
    end

  end
end
