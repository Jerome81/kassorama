require "net/http"
require "json"
require "uri"

class PrinterClient
  class PrintError < StandardError
    attr_reader :http_status, :response_body

    def initialize(message, http_status: nil, response_body: nil)
      super(message)
      @http_status = http_status
      @response_body = response_body
    end
  end

  DEFAULT_PORT = 8081

  def self.print(ip:, port: DEFAULT_PORT, receipt_data:, open_timeout: 5, read_timeout: 15)
    target_ip = ip.to_s.strip
    if target_ip.empty?
      raise PrintError.new("Keine Drucker-IP für diese Kasse konfiguriert.")
    end

    target_port = (port.presence || DEFAULT_PORT).to_i
    payload = receipt_data.is_a?(Hash) ? receipt_data.dup : {}

    if %w[mock simulator test].include?(target_ip.downcase)
      target_ip = ENV.fetch("PRINTER_MOCK_HOST", "127.0.0.1")
      payload["mock"] = true
    end

    uri = URI::HTTP.build(host: target_ip, port: target_port, path: "/print")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout

    request = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
    request.body = JSON.generate(payload)

    response = if defined?(ActiveSupport::Dependencies) && ActiveSupport::Dependencies.respond_to?(:interlock)
                 ActiveSupport::Dependencies.interlock.permit_concurrent_loads { http.request(request) }
               else
                 http.request(request)
               end

    body = JSON.parse(response.body) rescue {}

    if response.code.to_i == 200 && body["success"]
      body
    else
      msg = body["result_message"].presence || body["error"].presence || "Quittungsdruck fehlgeschlagen (HTTP #{response.code})"
      raise PrintError.new(
        msg,
        http_status: response.code.to_i,
        response_body: body
      )
    end
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
    raise PrintError.new("Drucker-Server (#{target_ip}:#{target_port}) nicht erreichbar: #{e.message}", http_status: 502)
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise PrintError.new("Zeitüberschreitung bei der Kommunikation mit dem Quittungsdrucker (#{target_ip}:#{target_port})", http_status: 504)
  end

  def self.open_drawer(ip:, port: DEFAULT_PORT, pin: 2, open_timeout: 3, read_timeout: 5)
    target_ip = ip.to_s.strip
    if target_ip.empty?
      raise PrintError.new("Keine Drucker-IP für diese Kasse konfiguriert.")
    end

    target_port = (port.presence || DEFAULT_PORT).to_i
    query_params = { "pin" => pin.to_s }

    if %w[mock simulator test].include?(target_ip.downcase)
      target_ip = ENV.fetch("PRINTER_MOCK_HOST", "127.0.0.1")
      query_params["mock"] = "1"
    end

    uri = URI::HTTP.build(
      host: target_ip,
      port: target_port,
      path: "/open_drawer",
      query: URI.encode_www_form(query_params)
    )
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout

    request = Net::HTTP::Get.new(uri.request_uri)

    response = if defined?(ActiveSupport::Dependencies) && ActiveSupport::Dependencies.respond_to?(:interlock)
                 ActiveSupport::Dependencies.interlock.permit_concurrent_loads { http.request(request) }
               else
                 http.request(request)
               end

    body = JSON.parse(response.body) rescue {}

    if response.code.to_i == 200 && body["success"]
      body
    else
      msg = body["result_message"].presence || body["error"].presence || "Kassenschublade konnte nicht geöffnet werden (HTTP #{response.code})"
      raise PrintError.new(
        msg,
        http_status: response.code.to_i,
        response_body: body
      )
    end
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
    raise PrintError.new("Drucker-Server (#{target_ip}:#{target_port}) nicht erreichbar: #{e.message}", http_status: 502)
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise PrintError.new("Zeitüberschreitung beim Öffnen der Kassenschublade (#{target_ip}:#{target_port})", http_status: 504)
  end

  def self.try_open_drawer(cash_register)
    return nil unless cash_register&.printer_ip.present?

    open_drawer(ip: cash_register.printer_ip, port: cash_register.printer_port)
  rescue StandardError => e
    Rails.logger.warn("Cash drawer open failed for CashRegister ##{cash_register&.id}: #{e.message}") if defined?(Rails)
    nil
  end
end

