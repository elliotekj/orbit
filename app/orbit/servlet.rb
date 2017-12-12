class OrbitServlet < XMLRPC::WEBrickServlet
  attr_accessor :token

  def initialize(token)
    super()

    @token = token
  end

  def service(req, res)
    unless @token.nil?
      unless req.request_uri.to_s.match(/.*token=(\S+)$/)[1] == @token
        raise XMLRPC::FaultException.new(0, 'Token invalid')
      end
    end

    super
  end
end
