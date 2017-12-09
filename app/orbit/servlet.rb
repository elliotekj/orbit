require 'CGI'

class OrbitServlet < XMLRPC::WEBrickServlet
  attr_accessor :token

  def initialize(token)
    super()

    @token = token
  end

  def service(req, res)
    params = CGI.parse(req.query_string)
    unless params['token'][0] == @token
      raise XMLRPC::FaultException.new(0, 'Token invalid')
    end

    super
  end
end
