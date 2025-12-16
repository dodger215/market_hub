defmodule RealtimeMarket.Media.MediaStorage do
  @moduledoc """
  Handle media uploads and storage for product videos/images.
  """

  alias RealtimeMarket.Mongo

  @upload_dir "priv/static/uploads/"
  @allowed_types ~w(image/jpeg image/png image/gif video/mp4 video/quicktime audio/mpeg audio/mp3)
  @max_file_size 100 * 1024 * 1024 # 100MB

  @doc """
  Upload product media (video/image/audio).
  """
  def upload_product_media(product_id, file, media_type, metadata \\ %{}) do
    # Validate file
    case validate_file(file, media_type) do
      {:ok, validated_file} ->
        # Generate unique filename
        ext = get_extension(media_type)
        filename = "#{product_id}_#{Mongo.generate_uuid()}.#{ext}"
        filepath = Path.join(@upload_dir, filename)

        # Ensure directory exists
        File.mkdir_p!(@upload_dir)

        # Save file
        case File.copy(validated_file.path, filepath) do
          {:ok, _} ->
            # Store metadata in MongoDB
            media_id = Mongo.generate_uuid()

            media_doc = %{
              "_id" => media_id,
              "product_id" => product_id,
              "filename" => filename,
              "url" => "/uploads/#{filename}",
              "media_type" => media_type,
              "metadata" => Map.merge(metadata, %{
                "size" => file.size,
                "content_type" => file.content_type
              }),
              "created_at" => Mongo.now()
            }

            case Mongo.insert_one(Mongo.product_media_collection(), media_doc) do
              {:ok, _} ->
                # Generate thumbnail for video
                if String.starts_with?(media_type, "video/") do
                  generate_video_thumbnail(filepath, media_id)
                end

                {:ok, media_doc}

              {:error, reason} ->
                File.rm!(filepath)
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Upload audio for product media (background music for Reels).
  """
  def upload_audio(product_id, file, metadata \\ %{}) do
    case validate_file(file, "audio/mpeg") do
      {:ok, validated_file} ->
        ext = get_extension("audio/mpeg")
        filename = "#{product_id}_audio_#{Mongo.generate_uuid()}.#{ext}"
        filepath = Path.join(@upload_dir, filename)

        File.mkdir_p!(@upload_dir)

        case File.copy(validated_file.path, filepath) do
          {:ok, _} ->
            # Store in audio collection
            audio_id = Mongo.generate_uuid()

            audio_doc = %{
              "_id" => audio_id,
              "product_id" => product_id,
              "filename" => filename,
              "url" => "/uploads/#{filename}",
              "type" => "audio",
              "metadata" => metadata,
              "created_at" => Mongo.now()
            }

            Mongo.insert_one(Mongo.audio_collection(), audio_doc)
            {:ok, audio_doc}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_file(file, expected_type) do
    cond do
      file.size > @max_file_size ->
        {:error, :file_too_large}

      file.content_type not in @allowed_types ->
        {:error, :invalid_file_type}

      not String.starts_with?(file.content_type, expected_type) ->
        {:error, :type_mismatch}

      true ->
        {:ok, file}
    end
  end

  defp get_extension(content_type) do
    case content_type do
      "image/jpeg" -> "jpg"
      "image/png" -> "png"
      "image/gif" -> "gif"
      "video/mp4" -> "mp4"
      "video/quicktime" -> "mov"
      "audio/mpeg" -> "mp3"
      "audio/mp3" -> "mp3"
      _ -> "bin"
    end
  end

  defp generate_video_thumbnail(video_path, media_id) do
    # Use ffmpeg to generate thumbnail
    thumbnail_path = String.replace(video_path, ~r/\.[^\.]+$/, "_thumb.jpg")

    System.cmd("ffmpeg", [
      "-i", video_path,
      "-ss", "00:00:01",
      "-vframes", "1",
      "-vf", "scale=640:-1",
      thumbnail_path
    ])

    # Store thumbnail reference
    if File.exists?(thumbnail_path) do
      thumbnail_url = String.replace(thumbnail_path, @upload_dir, "/uploads/")

      Mongo.update_one(
        Mongo.product_media_collection(),
        %{"_id" => media_id},
        %{"$set" => %{"thumbnail_url" => thumbnail_url}}
      )
    end
  end
end
