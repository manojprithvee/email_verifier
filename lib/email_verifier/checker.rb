require 'net/smtp'
require 'dnsruby'

class EmailVerifier::Checker

  ##
  # Returns server object for given email address or throws exception
  # Object returned isn't yet connected. It has internally a list of 
  # real mail servers got from MX dns lookup
  def initialize(address)
    beginning_time = Time.now
    @email   = address
    _, @domain  = address.split("@")
    @servers = list_mxs @domain
    raise EmailVerifier::NoMailServerException.new("No mail server for #{address}") if @servers.empty?
    @smtp    = nil

    # this is because some mail servers won't give any info unless 
    # a real user asks for it:
    @user_email = EmailVerifier.config.verifier_email
    _, @user_domain = @user_email.split "@"
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def list_mxs(domain)
    beginning_time = Time.now
    return [] unless domain
    res = Dnsruby::DNS.new
    mxs = []
    res.each_resource(domain, 'MX') do |rr|
      mxs << { priority: rr.preference, address: rr.exchange.to_s }
    end
    mxs.sort_by { |mx| mx[:priority] }
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  rescue Dnsruby::NXDomain
    raise EmailVerifier::NoMailServerException.new("#{domain} does not exist") 
  end

  def is_connected
    beginning_time = Time.now
    !@smtp.nil?
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def connect
    beginning_time = Time.now
    begin
      server = next_server
      raise EmailVerifier::OutOfMailServersException.new("Unable to connect to any one of mail servers for #{@email}") if server.nil?
      @smtp = Net::SMTP.start server[:address], 25, @user_domain
      return true
      end_time = Time.now
      puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
    rescue EmailVerifier::OutOfMailServersException => e
      raise EmailVerifier::OutOfMailServersException, e.message
    rescue => e
      retry
    end
  end

  def next_server
    beginning_time = Time.now
    @servers.shift
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def verify
    beginning_time = Time.now
    self.mailfrom @user_email
    self.rcptto(@email).tap do
      close_connection
    end
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def close_connection
    beginning_time = Time.now
    @smtp.finish if @smtp && @smtp.started?
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def mailfrom(address)
    beginning_time = Time.now
    ensure_connected

    ensure_250 @smtp.mailfrom(address)
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def rcptto(address)
    beginning_time = Time.now
    ensure_connected
   
    begin
      ensure_250 @smtp.rcptto(address)
    rescue => e
      if e.message[/^550/]
        return false
      else
        raise EmailVerifier::FailureException.new(e.message)
      end
    end
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def ensure_connected
    beginning_time = Time.now
    raise EmailVerifier::NotConnectedException.new("You have to connect first") if @smtp.nil?
    end_time = Time.now
    puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
  end

  def ensure_250(smtp_return)
    beginning_time = Time.now
    if smtp_return.status.to_i == 250
      return true
      end_time = Time.now
      puts __method__.to_s+" Time elapsed #{(end_time - beginning_time)*1000} milliseconds"
    else
      raise EmailVerifier::FailureException.new "Mail server responded with #{smtp_return.status} when we were expecting 250"
    end
  end
end
