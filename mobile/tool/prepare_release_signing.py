"""Prepare a private, persistent release keystore from GitHub Actions secrets."""
import base64
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    names = ("ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD")
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise SystemExit("Configure the persistent signing secrets first: " + ", ".join(missing)
                         + ". Release builds must never fall back to a new debug key.")
    mobile = Path(__file__).resolve().parents[1]
    try:
        data = base64.b64decode(os.environ["ANDROID_KEYSTORE_BASE64"], validate=True)
    except ValueError:
        raise SystemExit("ANDROID_KEYSTORE_BASE64 must be the exact single-line value from your private signing bundle.") from None
    if not data or len(data) > 65536:
        raise SystemExit("Invalid signing keystore size")
    destination = mobile / "android/app/safar-release.p12"
    destination.write_bytes(data)
    destination.chmod(0o600)
    try:
        with tempfile.TemporaryDirectory(prefix="safar-public-cert-") as folder:
            certificate = Path(folder) / "certificate.der"
            result = subprocess.run(["keytool", "-exportcert", "-storetype", "PKCS12",
                "-keystore", str(destination), "-alias", os.environ["ANDROID_KEY_ALIAS"],
                "-storepass:env", "ANDROID_KEYSTORE_PASSWORD", "-file", str(certificate)],
                capture_output=True)
            if result.returncode != 0:
                raise SystemExit("Cannot open the persistent keystore. Check the four signing secrets.")
            expected = (mobile / "android/release-cert.sha256").read_text().strip().lower()
            if hashlib.sha256(certificate.read_bytes()).hexdigest() != expected:
                raise SystemExit("Wrong signing identity. Use the original Safar release key, not a newly generated key.")
    except BaseException:
        destination.unlink(missing_ok=True)
        raise
    print("Persistent Safar release signing identity verified.")


if __name__ == "__main__":
    main()
