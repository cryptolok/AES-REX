![](https://github.com/cryptolok/AES-REX/raw/master/logo.png)

Properties:
* Cross-platform
* Minimalism
* Simplicity
* Application Independable
* Process Injection
* Cipher Mode Detection
* Cipher Length Detection
* Ressource-efficency

Dependencies:
* **Unix** - should work on any Unix-based OS
	- BASH - the whole script
	- root privileges (optional)

Limitations:
* AES keys only
* Cipher mode detection is probabilistic
* Limited IV detection
* Limited library support
* Needs proper user privileges and memory authorizations

# How it works

You may already heard or even used my [CryKeX](https://github.com/cryptolok/CryKeX) project that does pretty the same thing, but differently. Whereas CryKeX extracts cryptographic keys from volatile memory (RAM), AES-REX will extract it from registers.

[AES](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard) (Rijndael) is a modern standard for symmetric cryptography, it even has been implemented in modern CPUs, so that there are specific assembly instruction to perform cryptographic operations - [AES-NI](https://software.intel.com/en-us/articles/intel-advanced-encryption-standard-instructions-aes-ni), which uses XMM 128-bit [SSE](https://en.wikipedia.org/wiki/Streaming_SIMD_Extensions) registers. This makes the cipher more fast and even more secure to some extent, however, if a process is debugged and the values of those registers are inspected just before the encryption, since the key is stored there, it is possible to extract it without searching in the whole memory. Moreover, these instructions are included in cryptographic libraries, so all software will rely on it.

Basically, the process is debugged, its cryptographic library location is revealed, the corresponding assembly instructions are found and their offset addresses are calculated based on current virtual memory. If such address is used, then the registers are inspected, thus extracting the keys used for encryption.

By using such technique it is also possible to change and swap a key for another one on the fly. It's even possible to extract obfuscated keys (like LUKS) and those protected by TPM (like BitLocker) since they will be in registers anyway.

Cipher mode is detected based on R registers values statistics, which varies from one implementation to another, but could be determined separately.

IV detection is possible, but it depends from cipher mode and given that the detection of the last one isn't that great at the moment, the IV isn't a priority, besides it shouldn't be a secret anyway.

Cipher key length is determined based on static R registers values that contain number of rounds, thus more precise.

Currently, project supports libcrypto < v3 librabry (Debian based OpenSSL, OpenSSH and OpenVPN). Other libraries (and OSes), like libgcrypt (browsers, containers and pgp-like) are partially supported and require further work and reverse engineering.

Of course, it wouldn't work on a custom AES-NI implementation or a code that doesn't use it at all, thus it's not a universal solution, but very effective 99% of a time.

More technical details will be published in an separate article that will be released soon, meanwhile, you are free to read whole 100 lines of code.

## HowTo

Installing dependencies:
```bash
sudo apt install gdb || echo 'yet another packet manager'
```

An interactive example for OpenSSL AES keys:
```bash
openssl aes-128-ecb -nosalt -out testAES.enc
```
Enter a password twice, then some text and before terminating:
```bash
aes-rex.sh openssl
```
Finally, press Ctrl+D 2 times and [check](http://aes.online-domain-tools.com/) the result.

Let's extract keys from SSH:
```bash
echo 'Ciphers aes256-gcm@openssh.com' >> /etc/ssh/sshd_config
ssh user@server
aes-rex.sh ssh
```

From OpenVPN:
```bash
echo 'cipher AES-256-CBC' >> /etc/openvpn/server.conf
openvpn yourConf.ovpn
sudo aes-rex.sh openvpn
```

### Notes

Feel free to contribute and make some tests. Crypto libraries docs and reverse are most welcome.

> "Cryptography is typically bypassed, not penetrated."

Adi Shamir

