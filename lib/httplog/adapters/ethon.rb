# frozen_string_literal: true

if defined?(Ethon)
  module Ethon
    class Easy
      attr_accessor :action_name

      module Http
        alias orig_http_request http_request
        def http_request(url, action_name, options = {})
          @http_log = options.merge(method: action_name) # remember this for compact logging
          orig_http_request(url, action_name, options)

          self.on_body do |bdata|
            @http_log[:resp_body] ||= StringIO.new
            @http_log[:resp_body].write(bdata)
          end

          self.on_headers do |obj|
            @http_log[:resp_headers] ||= obj.response_headers
          end

          self.on_complete do |obj|
            
            
            # Not sure where the actual status code is stored - so let's
            # extract it from the response header.
            encodings = @http_log[:resp_headers].scan(/Content-Encoding: (\S+)/i).flatten.first
            content_type = @http_log[:resp_headers].scan(/Content-Type: (\S+(; charset=\S+)?)/i).flatten.first

            # Hard to believe that Ethon wouldn't parse out the headers into
            # an array; probably overlooked it. Anyway, let's do it ourselves:
            @http_log[:resp_headers] = @http_log[:resp_headers].split(/\r?\n/).drop(1)

            response_body = @http_log[:resp_body]
            response_body.rewind

            HttpLog.call(
              method: @http_log[:method],
              url: @url,
              request_body: @http_log[:body],
              request_headers: @http_log[:headers],
              response_code: response_code,
              response_body: response_body.read,
              response_headers: @http_log[:resp_headers].map { |header| header.split(/:\s/) }.to_h,
              benchmark: @http_log[:bm],
              encoding: encodings,
              content_type: content_type,
              mask_body: HttpLog.masked_body_url?(url)
            )
            return_code
          end

        end
      end

      module Operations
        alias orig_perform perform
        def perform
          return orig_perform unless HttpLog.url_approved?(url)

          @http_log[:bm] = Benchmark.realtime { orig_perform }

          return_code
        end
      end
    end
  end
end
