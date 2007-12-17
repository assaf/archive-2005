class AttributesController < ApplicationController

  # GET to /domains/:domain_id/items/:item_id/attributes
  #
  # JSON:  Returns { name: [values]* }
  # XML:   Returns <attributes><name>values</name></attributes>
  def index
    response = getsify('Action'=>'GetAttributes')
    attributes = response.get_elements('/GetAttributesResponse/GetAttributesResult/Attribute').
      map { |elem| [elem.get_text('Name').to_s, elem.get_text('Value').to_s ] }.
      inject({}) { |hash, (name, value)| hash.update(name=>Array(hash[name]) << value) }
    respond_to do |format|
      format.json { render :json=>attributes }
      format.xml  { render :xml=>attributes.to_xml(:root=>'attributes') }
    end
  end

  # POST to /domains/:domain_id/items/:item_id/attributes
  #
  # URL/multipart:  Use name=value pairs, use name[]=value for arrays.
  # JSON:           Hash of name/value pairs, value can be array.
  # XML:            <attributes> element containing <name>value</name> pairs.
  def create
    getsify attributes, 'Action'=>'PutAttributes'
    head :created, :location=>domain_item_url(params['domain_id'], params['item_id'])
  end

  # GET to /domains/:domain_id/items/:item_id/attributes/:name
  #
  # JSON:  Returns [values*]
  # XML:   Returns <values><value>value</value></values>
  def show
    response = getsify('Action'=>'GetAttributes')
    values = response.get_elements('/GetAttributesResponse/GetAttributesResult/Attribute').
      map { |elem| elem.get_text('Value').to_s }
    respond_to do |format|
      format.json { render :json=>values }
      format.xml  { render :xml=>values.to_xml(:root=>'values') }
    end
  end

  # POST to /domains/:domain_id/items/:item_id/attributes/:name
  # Request body/value parameter is new attribute value, added to any existing values.
  def append
    getsify 'Action'=>'PutAttributes', 'Attribute.0.Value'=>(params['value'] || request.body.read)
    head :ok 
  end

  # PUT to /domains/:domain_id/items/:item_id/attributes/:name
  # Request body/value parameter is new attribute value, replacing existing values.
  def update
    getsify 'Action'=>'PutAttributes', 'Attribute.0.Value'=>(params['value'] ||request.body.read), 'Replace'=>'true'
    head :ok 
  end

  # DELETE to /domains/:domain_id/items/:item_id/attributes/:name
  # Deletes all values of this attribute.
  #
  # DELETE to /domains/:domain_id/items/:item_id/attributes/:name/:value
  # Deletes given value for this attribute.
  def destroy
    if params['value']
      getsify 'Action'=>'DeleteAttributes', 'Attribute.0.Value'=>params['value']
    else
      getsify 'Action'=>'DeleteAttributes'
    end
    head :ok 
  end

protected

  def getsify(*args)
    args << { 'DomainName'=>params['domain_id'], 'ItemName'=>params['item_id'] }
    args << { 'Attribute.0.Name'=>params['id'] } if params['id']
    super *args
  end

end
