class PhotoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_white_list
     %w(jpg jpeg gif png)
  end

 version :p303x498 do
   process :resize_to_fit => [303,498]
 end
 # version :p540x160 do
 #   process :resize_to_fit => [540, 160]
 #   #process :resize_to_fit => [540,160]
 # end
 # version :p530x150 do
 #   process :resize_to_fit => [530,150]
 # end
end