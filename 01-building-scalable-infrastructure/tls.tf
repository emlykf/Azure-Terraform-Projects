resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ssl_cert" {
  #private_key_pem = file("private_key.pem")
  private_key_pem = tls_private_key.private_key.private_key_pem   # use the key generated above to sign this cert

  subject {
    common_name  = "poppy-gmbh.site"
    organization = "Learning Project"
  }

  validity_period_hours = 8760    # how long the cert stays valid (1 year)

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
