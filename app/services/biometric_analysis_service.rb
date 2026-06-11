require 'json'
require 'open3'
require 'fileutils'
require 'securerandom'

class BiometricAnalysisService
  class AnalysisError < StandardError
    attr_reader :payload

    def initialize(payload)
      @payload = payload
      super(payload['message'] || 'Biometric analysis failed')
    end
  end

  # image_source can be a String path, an ActionDispatch::Http::UploadedFile,
  # an ActiveStorage::Blob, or an object that responds to :path
  def initialize(image_source)
    @image_source = image_source
  end

  def call
    python_bin = Rails.root.join('.venv', 'bin', 'python3').to_s
    script_path = Rails.root.join('gercek_analiz.py').to_s

    unless File.exist?(python_bin)
      Rails.logger.error("BiometricAnalysisService Error: Python executable not found at #{python_bin}")
      raise AnalysisError.new({ 'status' => 'error', 'message' => "Python executable not found at #{python_bin}" })
    end

    unless File.exist?(script_path)
      Rails.logger.error("BiometricAnalysisService Error: Python script not found at #{script_path}")
      raise AnalysisError.new({ 'status' => 'error', 'message' => "Python script not found" })
    end

    real_path = resolve_to_persistent_path(@image_source)

    unless real_path && File.exist?(real_path)
      Rails.logger.error("BiometricAnalysisService Error: Resolved image path not found: #{real_path}")
      raise AnalysisError.new({ 'status' => 'error', 'message' => "Image file not found or inaccessible" })
    end

    begin
      stdout, stderr, status = Open3.capture3(python_bin, script_path, real_path)

      # Geliştirme sürecinde logları rahat görebilmemiz için her şeyi Rails loguna yazıyoruz
      Rails.logger.info("BiometricAnalysisService STDOUT: #{stdout}") unless stdout.to_s.strip.empty?
      Rails.logger.warn("BiometricAnalysisService STDERR: #{stderr}") unless stderr.to_s.strip.empty?

      # 1. ÖNCE PARSE ET: Python scripti hata durumunda exit(1) dönse bile 
      # STDOUT'a yapılandırılmış bir JSON hatası basıyor olabilir. 
      parsed_output = nil
      begin
        parsed_output = JSON.parse(stdout) if stdout.present?
      rescue JSON::ParserError
        # STDOUT geçerli bir JSON değilse fall-through yapıp durum kontrolüne geçecek
      end

      # Eğer Python bize geçerli bir JSON döndüyse öncelik onundur
      if parsed_output.is_a?(Hash)
        if parsed_output['status'] == 'error'
          raise AnalysisError.new(parsed_output)
        elsif status.success?
          return parsed_output
        end
      end

      # 2. DURUM KONTROLÜ: Eğer üstteki JSON kontrolünden geçemediyse ve çıkış kodu başarısızsa
      unless status.success?
        Rails.logger.error("BiometricAnalysisService Error: Python script failed with exit code #{status.exitstatus}")
        
        # Stderr içindeki tqdm (indirme çubuğu) ilerleme yazılarını temizleyip temiz bir mesaj bırakıyoruz
        clean_stderr = stderr.to_s.lines.reject { |l| l.include?('%|') || l.include?('Loading weights') }.join("\n").strip
        error_msg = clean_stderr.presence || "Python script failed to execute (Exit status: #{status.exitstatus})"
        
        raise AnalysisError.new({ 'status' => 'error', 'message' => error_msg })
      end

      # Eğer exit 0 oldu ama çıktı JSON değilse
      raise AnalysisError.new({ 'status' => 'error', 'message' => "Python script completed successfully but returned invalid output format" })

    rescue AnalysisError
      raise
    rescue => e
      Rails.logger.error("BiometricAnalysisService Unexpected Error: #{e.inspect}")
      raise AnalysisError.new({ 'status' => 'error', 'message' => "Unexpected error occurred during biometric analysis: #{e.message}" })
    end
  end

  private

  def resolve_to_persistent_path(source)
    if defined?(ActiveStorage::Blob) && source.respond_to?(:key) && source.respond_to?(:download)
      begin
        if ActiveStorage::Blob.service.respond_to?(:path_for)
          return ActiveStorage::Blob.service.path_for(source.key)
        end
        return download_blob_to_tmp(source)
      rescue => e
        Rails.logger.warn("BiometricAnalysisService: failed to resolve blob path: #{e.message}")
        return download_blob_to_tmp(source)
      end
    end

    if source.respond_to?(:path) && File.exist?(source.path)
      return safe_copy_if_ephemeral(source.path)
    end

    if source.is_a?(String)
      return safe_copy_if_ephemeral(source)
    end

    nil
  end

  def download_blob_to_tmp(blob)
    dest_dir = Rails.root.join('tmp', 'tracepaw_analysis')
    FileUtils.mkdir_p(dest_dir)
    ext = blob.filename.extension_with_delimiter.presence || ''
    dest = dest_dir.join("#{SecureRandom.hex(12)}#{ext}")
    File.open(dest, 'wb') { |f| f.write(blob.download) }
    dest.to_s
  end

  def safe_copy_if_ephemeral(path)
    return nil unless File.exist?(path)

    ephemeral_prefixes = [Rails.root.join('tmp').to_s, '/tmp', '/var/folders']
    if ephemeral_prefixes.any? { |p| path.start_with?(p) }
      dest_dir = Rails.root.join('tmp', 'tracepaw_analysis')
      FileUtils.mkdir_p(dest_dir)
      dest = dest_dir.join("#{SecureRandom.hex(12)}#{File.extname(path)}")
      FileUtils.cp(path, dest)
      return dest.to_s
    end

    path
  end
end