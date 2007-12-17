class ItemsController < ApplicationController

  # GET to /domains/:domain_id/items?query=&limit=&token=
  #
  # Query parameters:
  # * query - Query expression
  # * limit - Maximum number of items to return
  # * token - Token returned from previous query
  #
  # JSON:  Returns [ url*, { token: ... }? ]
  # XML:   Returns <items><item>url</item><token>token</token>?</items>
  def index
    query = { 'query'=>'QueryExpression', 'limit'=>'MaxNumberOfItems', 'token'=>'NextToken' }.
      inject({}) { |hash, (from, to)| params[from] ? hash.update(to=>params[from]) : hash }
    response = getsify(query, 'Action'=>'Query')
    items = response.get_elements('/QueryResponse/QueryResult/ItemName').map(&:text).
      map { |item| domain_item_url(params['domain_id'], item) }
    next_token = response.get_text('/QueryResponse/QueryResult/NextToken')
    respond_to do |format|
      format.json do
        items << { :token=>next_token.to_s } if next_token
        render :json=>items
      end
      format.xml  do
        render :xml=>items.to_xml(:root=>'items') { |xml| xml.tag! 'token', next_token.to_s if next_token }
      end
    end
  end

  # GET to /domains/:domain_id/items/:item_id/
  #
  # JSON:  Returns { name: [values]* }
  # XML:   Returns <attributes><name>values</name></attributes>
  def show
    response = getsify('Action'=>'GetAttributes')
    attributes = response.get_elements('/GetAttributesResponse/GetAttributesResult/Attribute').
      map { |elem| [elem.get_text('Name').to_s, elem.get_text('Value').to_s ] }.
      inject({}) { |hash, (name, value)| hash.update(name=>Array(hash[name]) << value) }
    respond_to do |format|
      format.json { render :json=>attributes }
      format.xml  { render :xml=>attributes.to_xml(:root=>'attributes') }
    end
  end

  # PUT to /domains/:domain_id/items/:item_id/
  #
  # URL/multipart:  Use name=value pairs, use name[]=value for arrays.
  # JSON:           Hash of name/value pairs, value can be array.
  # XML:            <attributes> element containing <name>value</name> pairs.
  #
  # Replaces the specified attributes with new values.
  def update
    getsify attributes, 'Action'=>'PutAttributes', 'Replace'=>'true'
    head :ok 
  end

  # POST to /domains/:domain_id/items/:item_id/
  #
  # URL/multipart:  Use name=value pairs, use name[]=value for arrays.
  # JSON:           Hash of name/value pairs, value can be array.
  # XML:            <attributes> element containing <name>value</name> pairs.
  #
  # Adds new values for the specified attributes.
  def append
    getsify attributes, 'Action'=>'PutAttributes'
    head :ok 
  end

  # DELETE to /domains/:domain_id/items/:item_id/
  # Deletes the item.
  #
  # DELETE to /domains/:domain_id/items/:item_id?foo=bar
  # Deletes the attribute foo with the value bar.
  #
  # DELETE to /domains/:domain_id/items/:item_id?foo[]=bar&foo[]=baz
  # Deletes the attribute foo with the values bar and baz.
  def destroy
    getsify attributes, 'Action'=>'DeleteAttributes'
    head :ok 
  end

protected

  def getsify(*args)
    args << { 'DomainName'=>params['domain_id'] }
    args << { 'ItemName'=>params['id'] } if params['id']
    super *args
  end

end
