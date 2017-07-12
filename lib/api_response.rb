class ApiResponse
  API_RESPONSES = YAML.load_file(
    "#{Rails.root.to_s}/config/api_responses.yml"
  ).with_indifferent_access

  class << self
    def replace_response(response, args)
      args.inject(response) do |replaced_response, (key, val)|
        replaced_response.gsub(/{#{key}}/, val.to_s)
      end
    end

    def get_response(namespace, response, args)
      replace_response(API_RESPONSES[namespace][response].sample, args)
    end
  end
end
