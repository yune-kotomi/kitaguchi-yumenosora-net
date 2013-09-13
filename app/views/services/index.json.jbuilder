json.array!(@services) do |service|
  json.extract! service, 
  json.url service_url(service, format: :json)
end
