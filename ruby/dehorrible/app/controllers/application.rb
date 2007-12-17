# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  before_filter :authenticate

  SDB_BASE_URI = 'https://sdb.amazonaws.com/'
  SDB_API_VERSION = '2007-11-07'
  SDB_SIGNATURE_VERSION = '0'

  # Make a GETSful request by tunnelling SOAP over GET.  Call with any number of Hash arguments,
  # which are then converted into request parameters.  Returns the response parsed into an REXML document.
  def getsify(*args)
    args = args.inject { |hash, args| hash.merge(args) }
    uri = URI(SDB_BASE_URI)
    uri.query = sign(args.merge('Version'=>SDB_API_VERSION, 'Timestamp'=>Time.now.iso8601)).to_query
    logger.debug "AWS GETSIFY: #{uri}"
    REXML::Document.new(uri.read)
  end

  # Returns a hash of attributes parsed from the request, useful for making a GETSful request.
  # Reads attributes values from the XML document <attributes>, JSON hash (requires json_request plugin),
  # or query parameters.  Returns a hash using the ever so annoying Attribute.n.Name/Attribute.n.Value.
  def attributes(param = nil)
    attributes = param || params['attributes'] || request.request_parameters.merge(request.query_parameters)
    attributes.inject({}) { |hash, (name, value)|
      hash.update("Attribute.#{hash.size >> 1}.Name"=>name, "Attribute.#{hash.size >> 1}.Value"=>value) }
  end

  rescue_from OpenURI::HTTPError do |error|
    render :status=>error.message, :text=>error.io.read
  end

private

  # HTTP Basic authentication accepts AWS id/key.
  def authenticate
    authenticate_or_request_with_http_basic request.domain do |id, secret|
      @amazon = { :id=>id, :secret=>secret }
    end
  end

  # Sign the parameters using the AWS id/key provided during authentication.
  def sign(params)
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('SHA1'), @amazon[:secret], params['Action'] + params['Timestamp'])
    params.merge('AWSAccessKeyId'=>@amazon[:id], 'SignatureVersion'=>SDB_SIGNATURE_VERSION, 'Signature'=>signature)
  end

  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  # protect_from_forgery # :secret => 'fbc58938fd7846b6b8e24e8946827c58'
end
