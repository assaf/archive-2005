class DomainsController < ApplicationController

  # GET to /domains/?limit=&token=
  #
  # Query parameters:
  # * limit - Maximum number of items to return
  # * token - Token returned from previous query
  #
  # JSON:  Returns [ url*, { token: ... }? ]
  # XML:   Returns <domains><domain>url</domain><token>token</token>?</domains>
  def index
    query = { 'limit'=>'MaxNumberOfItems', 'token'=>'NextToken' }.
      inject({}) { |hash, (from, to)| params[from] ? hash.update(to=>params[from]) : hash }
    dom = getsify(query, 'Action'=>'ListDomains')
    domains = dom.get_elements('/ListDomainsResponse/ListDomainsResult/DomainName').
      map(&:text).map { |name| { :name=>name, :url=>domain_url(name) } }
    next_token = response.get_text('/ListDomainsResponse/ListDomainsResult/NextToken')
    respond_to do |format|
      format.json do
        domains << { :next_token=>next_token.to_s } if next_token
        render :json=>domains
      end
      format.xml  do
        render :xml=>domains.to_xml(:root=>'domains') { |xml| xml.tag! 'next-token', next_token.to_s if next_token }
      end
    end
  end

  # POST to /domains/:domain_id
  # Request body/name parameter specify the domain name.
  def create
    name = params['name'] || request.body.read
    getsify 'Action'=>'CreateDomain', 'DomainName'=>name
    render :status=>:created, :location=>domain_url(name), :nothing=>true
  end

  # DELETE to /domains/:domain_id
  def destroy
    getsify 'Action'=>'DeleteDomain'
    head :ok 
  end

protected

  def getsify(*args)
    args << { 'DomainName'=>params['id'] } if params['id']
    super *args
  end

end
