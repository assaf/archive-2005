module ActionController
  # TestResponse for functional, CgiResponse for integration.
  class AbstractResponse
    StatusCodes::SYMBOL_TO_STATUS_CODE.each do |symbol, code|
      define_method("#{symbol}?") { self.response_code == code } unless instance_methods.include?("#{symbol}?")
    end
  end
end
