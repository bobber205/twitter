require 'twitter/rest/request'

module Twitter
  module REST
    module UploadUtils

      # Uploads images and videos. Videos require multiple requests and uploads in chunks of 5 Megabytes.
      # The only supported video format is mp4.
      #
      # @see https://dev.twitter.com/rest/public/uploading-media
      def upload(media,  extension = nil, media_category_prefix: 'tweet')
        puts "Upload called!"
        extension ||= File.extname(media)
        puts "Extension is #{extension}"
        if (extension == "tweet_gif")
          media_type = "image/gif"
          media_category = "tweet_gif"
        elsif (extension == ".gif") 
          media_category = "dm_gif"
          media_type = "image/gif"
        elsif (extension == ".jpeg")
          media_category = "dm_image"
          media_type = "image/jpeg"
        end
        
        return chunk_upload(media, media_type, media_category) if File.extname(media) == '.mp4'
        return chunk_upload(media, media_type, media_category) if extension  == '.gif' || extension == '.jpeg' || extension == 'tweet_gif'

        Twitter::REST::Request.new(self, :multipart_post, 'https://upload.twitter.com/1.1/media/upload.json', key: :media, file: media).perform
      end

      # rubocop:disable MethodLength
      def chunk_upload(media, media_type, media_category)
        puts "Chunk upload called --> #{media_type} === #{media_category} SHARED IS SET TO TRUE!"
        shared = true
        shared = false if media_category == "tweet_gif"
        init = Twitter::REST::Request.new(self, :post, 'https://upload.twitter.com/1.1/media/upload.json',
                                          command: 'INIT',
                                          media_type: media_type,
                                          shared: shared,
                                          media_category: media_category,
                                          total_bytes: media.size).perform
        until media.eof?
          chunk = media.read(5_000_000)
          seg ||= -1
          Twitter::REST::Request.new(self, :multipart_post, 'https://upload.twitter.com/1.1/media/upload.json',
                                     command: 'APPEND',
                                     media_id: init[:media_id],
                                     segment_index: seg += 1,
                                     key: :media,
                                     file: StringIO.new(chunk)).perform
        end

        media.close

        Twitter::REST::Request.new(self, :post, 'https://upload.twitter.com/1.1/media/upload.json',
                                   command: 'FINALIZE', media_id: init[:media_id]).perform
      end
      # rubocop:enable MethodLength
    end
  end
end
