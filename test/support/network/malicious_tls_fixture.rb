# frozen_string_literal: true

require "openssl"
require "socket"

module TestSupport
  module Network
    class MaliciousTlsFixture
      HOST = "127.0.0.1"
      DNS_NAME = "fixture.example"

      attr_reader :host, :port, :certificate_store

      def initialize
        @host = HOST
        @ca_key, @ca_certificate = build_ca
        @server_key, @server_certificate = build_server_certificate
        @certificate_store = OpenSSL::X509::Store.new
        @certificate_store.add_cert(@ca_certificate)
      end

      def start
        tcp = TCPServer.new(HOST, 0)
        @port = tcp.local_address.ip_port
        context = OpenSSL::SSL::SSLContext.new
        context.cert = @server_certificate
        context.key = @server_key
        @server = OpenSSL::SSL::SSLServer.new(tcp, context)
        @tcp = tcp
        @thread = Thread.new { accept_requests }
        self
      end

      def stop
        @tcp&.close
        @thread&.join(1)
        @thread = nil
        @server = nil
        @tcp = nil
      end

      private

      def accept_requests
        loop do
          socket = @server.accept
          handle(socket)
        rescue OpenSSL::SSL::SSLError, IOError, SystemCallError
          break if @tcp&.closed?
        end
      end

      def handle(socket)
        while (line = socket.gets)
          break if line == "\r\n"
        end
        body = "verified tls fixture"
        socket.write(
          "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n" \
            "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
        )
      ensure
        socket.close
      end

      def build_ca
        key = OpenSSL::PKey::RSA.new(2048)
        certificate = certificate_for("SearchOps Test CA", key.public_key, serial: 1)
        certificate.issuer = certificate.subject
        certificate.add_extension(extension_factory(certificate, certificate).create_extension(
          "basicConstraints", "CA:TRUE", true
        ))
        certificate.add_extension(extension_factory(certificate, certificate).create_extension(
          "keyUsage", "keyCertSign,cRLSign", true
        ))
        certificate.sign(key, OpenSSL::Digest::SHA256.new)
        [ key, certificate ]
      end

      def build_server_certificate
        key = OpenSSL::PKey::RSA.new(2048)
        certificate = certificate_for(DNS_NAME, key.public_key, serial: 2)
        certificate.issuer = @ca_certificate.subject
        factory = extension_factory(certificate, @ca_certificate)
        certificate.add_extension(factory.create_extension("basicConstraints", "CA:FALSE", true))
        certificate.add_extension(factory.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
        certificate.add_extension(factory.create_extension("extendedKeyUsage", "serverAuth", false))
        certificate.add_extension(factory.create_extension("subjectAltName", "DNS:#{DNS_NAME}", false))
        certificate.sign(@ca_key, OpenSSL::Digest::SHA256.new)
        [ key, certificate ]
      end

      def certificate_for(common_name, public_key, serial:)
        certificate = OpenSSL::X509::Certificate.new
        certificate.version = 2
        certificate.serial = serial
        certificate.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}")
        certificate.public_key = public_key
        certificate.not_before = Time.now - 60
        certificate.not_after = Time.now + 3600
        certificate
      end

      def extension_factory(certificate, issuer)
        factory = OpenSSL::X509::ExtensionFactory.new
        factory.subject_certificate = certificate
        factory.issuer_certificate = issuer
        factory
      end
    end
  end
end
