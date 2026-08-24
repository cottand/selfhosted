package macoskeychain

/*
#cgo LDFLAGS: -framework Security -framework CoreFoundation
#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

static void copyErrorMessage(CFErrorRef error, char **msgOut) {
	if (error == NULL) return;
	CFStringRef desc = CFErrorCopyDescription(error);
	if (desc == NULL) return;
	CFIndex len = CFStringGetMaximumSizeForEncoding(
		CFStringGetLength(desc), kCFStringEncodingUTF8) + 1;
	*msgOut = (char *)malloc(len);
	CFStringGetCString(desc, *msgOut, len, kCFStringEncodingUTF8);
	CFRelease(desc);
}

// findIdentity looks up an identity by label in the default keychain.
// On success, copies cert DER into certOut and retains a SecKeyRef into keyRefOut.
// keyTypeOut: 0=RSA, 1=EC. Returns 0 on success.
static int findIdentity(const char *label,
	unsigned char **certOut, int *certLenOut,
	void **keyRefOut, int *keyTypeOut,
	char **errMsgOut)
{
	CFStringRef cfLabel = CFStringCreateWithCString(
		kCFAllocatorDefault, label, kCFStringEncodingUTF8);
	if (cfLabel == NULL) return -1;

	CFMutableDictionaryRef query = CFDictionaryCreateMutable(
		kCFAllocatorDefault, 0,
		&kCFTypeDictionaryKeyCallBacks,
		&kCFTypeDictionaryValueCallBacks);

	CFDictionaryAddValue(query, kSecClass, kSecClassIdentity);
	CFDictionaryAddValue(query, kSecAttrLabel, cfLabel);
	CFDictionaryAddValue(query, kSecReturnRef, kCFBooleanTrue);
	CFDictionaryAddValue(query, kSecMatchLimit, kSecMatchLimitOne);

	CFTypeRef result = NULL;
	OSStatus status = SecItemCopyMatching(query, &result);
	CFRelease(query);
	CFRelease(cfLabel);

	if (status != errSecSuccess || result == NULL) {
		return (int)status;
	}

	SecIdentityRef identity = (SecIdentityRef)result;

	SecCertificateRef cert = NULL;
	status = SecIdentityCopyCertificate(identity, &cert);
	if (status != errSecSuccess) {
		CFRelease(identity);
		return (int)status;
	}

	CFDataRef certData = SecCertificateCopyData(cert);
	*certLenOut = (int)CFDataGetLength(certData);
	*certOut = (unsigned char *)malloc(*certLenOut);
	memcpy(*certOut, CFDataGetBytePtr(certData), *certLenOut);
	CFRelease(certData);
	CFRelease(cert);

	SecKeyRef privateKey = NULL;
	status = SecIdentityCopyPrivateKey(identity, &privateKey);
	CFRelease(identity);
	if (status != errSecSuccess) {
		free(*certOut);
		return (int)status;
	}

	CFDictionaryRef attrs = SecKeyCopyAttributes(privateKey);
	CFStringRef keyType = (CFStringRef)CFDictionaryGetValue(attrs, kSecAttrKeyType);
	if (CFStringCompare(keyType, kSecAttrKeyTypeRSA, 0) == kCFCompareEqualTo) {
		*keyTypeOut = 0;
	} else {
		*keyTypeOut = 1;
	}
	CFRelease(attrs);

	*keyRefOut = (void *)privateKey;
	return 0;
}

// signDigest signs a pre-hashed digest using the given SecKeyRef.
// Algorithm constants:
//   0=ECDSA-SHA256, 1=ECDSA-SHA384, 2=ECDSA-SHA512
//   3=RSA-PKCS1v15-SHA256, 4=RSA-PKCS1v15-SHA384, 5=RSA-PKCS1v15-SHA512
//   6=RSA-PSS-SHA256, 7=RSA-PSS-SHA384, 8=RSA-PSS-SHA512
static int signDigest(void *keyRef, int algorithm,
	const unsigned char *digest, int digestLen,
	unsigned char **sigOut, int *sigLenOut,
	char **errMsgOut)
{
	SecKeyRef key = (SecKeyRef)keyRef;

	SecKeyAlgorithm algo;
	switch (algorithm) {
		case 0: algo = kSecKeyAlgorithmECDSASignatureDigestX962SHA256; break;
		case 1: algo = kSecKeyAlgorithmECDSASignatureDigestX962SHA384; break;
		case 2: algo = kSecKeyAlgorithmECDSASignatureDigestX962SHA512; break;
		case 3: algo = kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256; break;
		case 4: algo = kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA384; break;
		case 5: algo = kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512; break;
		case 6: algo = kSecKeyAlgorithmRSASignatureDigestPSSSHA256; break;
		case 7: algo = kSecKeyAlgorithmRSASignatureDigestPSSSHA384; break;
		case 8: algo = kSecKeyAlgorithmRSASignatureDigestPSSSHA512; break;
		default: return -1;
	}

	CFDataRef digestData = CFDataCreate(kCFAllocatorDefault, digest, digestLen);
	CFErrorRef error = NULL;
	CFDataRef signature = SecKeyCreateSignature(key, algo, digestData, &error);
	CFRelease(digestData);

	if (signature == NULL) {
		copyErrorMessage(error, errMsgOut);
		if (error) CFRelease(error);
		return -2;
	}

	*sigLenOut = (int)CFDataGetLength(signature);
	*sigOut = (unsigned char *)malloc(*sigLenOut);
	memcpy(*sigOut, CFDataGetBytePtr(signature), *sigLenOut);
	CFRelease(signature);
	return 0;
}
*/
import "C"

import (
	"crypto"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"unsafe"
)

// LoadIdentity loads a TLS client identity (certificate + private key) from
// the macOS Keychain by its label. The private key never leaves the keychain;
// signing operations are delegated to the Security framework.
func LoadIdentity(label string) (tls.Certificate, error) {
	cLabel := C.CString(label)
	defer C.free(unsafe.Pointer(cLabel))

	var certData *C.uchar
	var certLen, keyType C.int
	var keyRef unsafe.Pointer
	var errMsg *C.char

	rc := C.findIdentity(cLabel, &certData, &certLen, &keyRef, &keyType, &errMsg)
	if rc != 0 {
		return tls.Certificate{}, keychainError(int(rc), errMsg)
	}

	certBytes := C.GoBytes(unsafe.Pointer(certData), certLen)
	C.free(unsafe.Pointer(certData))

	cert, err := x509.ParseCertificate(certBytes)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("macoskeychain: parsing certificate: %w", err)
	}

	signer := &keychainSigner{
		keyRef: keyRef,
		pub:    cert.PublicKey,
		isEC:   keyType == 1,
	}

	return tls.Certificate{
		Certificate: [][]byte{certBytes},
		PrivateKey:  signer,
		Leaf:        cert,
	}, nil
}

func keychainError(status int, cMsg *C.char) error {
	msg := ""
	if cMsg != nil {
		msg = C.GoString(cMsg)
		C.free(unsafe.Pointer(cMsg))
	}
	if status == -25300 {
		return fmt.Errorf("macoskeychain: identity not found")
	}
	if msg != "" {
		return fmt.Errorf("macoskeychain: Security framework error %d: %s", status, msg)
	}
	return fmt.Errorf("macoskeychain: Security framework error %d", status)
}

// keychainSigner implements crypto.Signer by delegating to the macOS
// Security framework via SecKeyCreateSignature. The private key never
// leaves the keychain.
type keychainSigner struct {
	keyRef unsafe.Pointer
	pub    crypto.PublicKey
	isEC   bool
}

func (s *keychainSigner) Public() crypto.PublicKey {
	return s.pub
}

func (s *keychainSigner) Sign(_ io.Reader, digest []byte, opts crypto.SignerOpts) ([]byte, error) {
	algo, err := s.algorithm(opts)
	if err != nil {
		return nil, err
	}

	var sigData *C.uchar
	var sigLen C.int
	var errMsg *C.char

	rc := C.signDigest(s.keyRef, algo,
		(*C.uchar)(unsafe.Pointer(&digest[0])), C.int(len(digest)),
		&sigData, &sigLen, &errMsg)
	if rc != 0 {
		return nil, keychainError(int(rc), errMsg)
	}
	defer C.free(unsafe.Pointer(sigData))

	return C.GoBytes(unsafe.Pointer(sigData), sigLen), nil
}

func (s *keychainSigner) algorithm(opts crypto.SignerOpts) (C.int, error) {
	hash := opts.HashFunc()

	if s.isEC {
		switch hash {
		case crypto.SHA256:
			return 0, nil
		case crypto.SHA384:
			return 1, nil
		case crypto.SHA512:
			return 2, nil
		}
		return 0, fmt.Errorf("macoskeychain: unsupported EC hash %v", hash)
	}

	if _, isPSS := opts.(*rsa.PSSOptions); isPSS {
		switch hash {
		case crypto.SHA256:
			return 6, nil
		case crypto.SHA384:
			return 7, nil
		case crypto.SHA512:
			return 8, nil
		}
		return 0, fmt.Errorf("macoskeychain: unsupported RSA-PSS hash %v", hash)
	}

	switch hash {
	case crypto.SHA256:
		return 3, nil
	case crypto.SHA384:
		return 4, nil
	case crypto.SHA512:
		return 5, nil
	}
	return 0, fmt.Errorf("macoskeychain: unsupported RSA hash %v", hash)
}
