require '../utils/uuid.core.js'

module UUIDGenerator
  def self.generate
    `UUID.generate()`
  end
end
