postMessage
  type: 'status'
  message: 'Importing JSRSASign library ...'

importScripts 'jsrsasign-4.7.0-all-min.js'

j = KJUR

keyUtil    = KEYUTIL
asn1Util   = j.asn1.ASN1Util
cryptoUtil = j.crypto.Util

# Shorts of ASN.1 Structure

SEQUENCE = (arr) ->
  new j.asn1.DERSequence
    'array': arr

SET = (arr) ->
  new j.asn1.DERSet
    'array': arr

INTERGER = (num) ->
  new j.asn1.DERInteger
    'int': num

PRTSTR = (str) ->
  new j.asn1.DERPrintableString
    'str': str

UTF8STR = (str) ->
  new j.asn1.DERUTF8String
    'str': str

BITSTR = (hex) ->
  new j.asn1.DERBitString
    'hex': hex

OID = (oid) ->
  j.asn1.x509.OID.name2obj oid

TAG = (tag) ->
  new j.asn1.DERTaggedObject
    'tag': tag or 'a0'

DERNULL = () ->
   new j.asn1.DERNull()


generateKeyPair = (len) ->
  ret = {}
  tbl = [
    324 # 1024
    588 # 2048
  ]

  keyPair = keyUtil.generateKeypair "RSA", len
  privateKeyObj = ret.privateKeyObj = keyPair.prvKeyObj
  publicKeyObj  = ret.publicKeyObj  = keyPair.pubKeyObj

  # workaround for https://github.com/kjur/jsrsasign/issues/37
  privateKeyObj.isPrivate = true
  privateKeyPEM = ret.privateKeyPEM = keyUtil.getPEM privateKeyObj, "PKCS8PRV"
  privateKeyHex = ret.privateKeyHex = keyUtil.getHexFromPEM privateKeyPEM, "PRIVATE KEY"

  publicKeyPEM  = ret.publicKeyPEM = keyUtil.getPEM publicKeyObj
  publicKeyHex  = ret.publicKeyHex = keyUtil.getHexFromPEM publicKeyPEM, "PUBLIC KEY"

  if tbl.indexOf(ret.publicKeyHex.length) is -1
    return false
  ret

generateCSR = (data, keyPair, alg) ->
  alg = alg or 'SHA256withRSA'

  # CertificationRequestInfo
  certificateRequestInfo = SEQUENCE [
    INTERGER 0
    SEQUENCE [
      SET [
        SEQUENCE [
          OID     "countryName"
          PRTSTR  data.countryName
        ]
      ]
      SET [
        SEQUENCE [
          OID     "stateOrProvinceName"
          UTF8STR data.stateOrProvinceName
        ]
      ]
      SET [
        SEQUENCE [
          OID     "locality"
          UTF8STR data.locality
        ]
      ]
      SET [
        SEQUENCE [
          OID     "organization"
          UTF8STR data.organization
        ]
      ]
      SET [
        SEQUENCE [
          OID     "commonName"
          UTF8STR data.commonName
        ]
      ]
    ]
    new j.asn1.x509.SubjectPublicKeyInfo(keyPair.publicKeyObj)
    TAG()
  ]

  # Signature CertificationRequestInfo
  sig = new j.crypto.Signature
    alg: alg
  sig.init(keyPair.privateKeyPEM)
  sig.updateHex(certificateRequestInfo.getEncodedHex())

  # CertificationRequest
  SEQUENCE [
    certificateRequestInfo
    SEQUENCE [
      OID alg
      DERNULL()
    ]
    BITSTR '00' + sig.sign()
  ]

onmessage = (e) ->
  data = e.data.workload
  # Generate Key Pair
  postMessage
    type: 'status'
    message: 'Generating private key ...'

  keyPair = false
  while 1
    keyPair = generateKeyPair(parseInt(data.keySize))
    if keyPair is false
      postMessage
        type: 'status'
        message: 'Regenerating private key ...'
    else
      break

  # Generate Certificate Signing Request
  postMessage
    type: 'status'
    message: 'Generating CSR ...'
  CSR = generateCSR data, keyPair, "SHA256withRSA"


  # Generate Certificate Signing Request
  postMessage
    type: 'status'
    message: 'Converting CSR to PEM format ...'
  CSRPEM = asn1Util.getPEMStringFromHex(CSR.getEncodedHex(), "CERTIFICATE REQUEST")


  postMessage
    type: 'private'
    pem: keyPair.privateKeyPEM


  postMessage
    type: 'csr'
    pem: CSRPEM

  postMessage
    type: 'done'
