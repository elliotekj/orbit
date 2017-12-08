require 'CGI'

class OrbitServlet < XMLRPC::WEBrickServlet
  attr_accessor :token

  def initialize(token)
    super()

    @token = token
  end

  def service(req, res)
    params = CGI.parse(req.query_string)
    raise XMLRPC::FaultException.new(0, 'Login invalid') unless params['token'][0] == @token

    super
  end
end
