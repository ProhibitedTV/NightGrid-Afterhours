# Verify the private build delivery

After the local creator runner succeeds, keep the expected full integration commit separately (git rev-parse HEAD). Run the following against the delivered folder, including after copying it to another drive:

    python tools/verify_creator_delivery.py "D:/private-playtests/new-candidate" --revision FULL_40_CHARACTER_COMMIT

The verifier reads the checksummed payload files, rejects missing, duplicate and malformed entries, compares source identity and the four pinned character hashes in the manifest, and checks recorded build steps. It does not launch the game, write files, verify arbitrary additional folder contents, or imply rights approval, human listening, actual PCK asset presence, signature authenticity or native acceptance. SHA256SUMS is not a digital signature; retain the original manifest separately if authenticity matters. Use the existing packaged-cast diagnostic for actual private PCK hashes and the creator playtest guide for gameplay verification.
