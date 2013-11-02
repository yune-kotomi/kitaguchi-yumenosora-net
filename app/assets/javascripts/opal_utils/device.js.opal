require '../utils/device.js'

module Device
  def self.mobile?
    `device.mobile()`
  end
end

