require "openssl"

CIPHER = "AES-256-CBC"
SALT = "V\x11\x97\xA6r\xEF[\xFE"
PASSWORD = "mypassword"

class Coder

  def initialize
    cipher = OpenSSL::Cipher.new(CIPHER)
    key_iv = OpenSSL::PKCS5.pbkdf2_hmac_sha1(PASSWORD, SALT, 2000, cipher.key_len + cipher.iv_len)
    @key = key_iv[0, cipher.key_len]
    @iv = key_iv[cipher.key_len, cipher.iv_len]

    @encoder = OpenSSL::Cipher.new(CIPHER)
    @encoder.encrypt
    @encoder.key = @key

    @decoder = OpenSSL::Cipher.new(CIPHER)
    @decoder.decrypt
    @decoder.key = @key
  end

  def encode(data)
    @encoder.iv = @iv
    @encoder.update(data) + @encoder.final
  end

  def decode(data)
    @decoder.iv = @iv
    @decoder.update(data) + @decoder.final
  end
end
