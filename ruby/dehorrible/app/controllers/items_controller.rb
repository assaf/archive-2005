class ItemsController < ApplicationController

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
