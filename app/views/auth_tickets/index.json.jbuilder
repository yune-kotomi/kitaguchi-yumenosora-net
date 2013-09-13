json.array!(@auth_tickets) do |auth_ticket|
  json.extract! auth_ticket, 
  json.url auth_ticket_url(auth_ticket, format: :json)
end
