# Verify the delivered creator package

After staging all four exact candidates, running local office actor validation and exporting a new Windows EXE/PCK, run the **exported executable** from its artifact directory:

    .\NightGrid-Afterhours.exe --headless -- --verify-creator-pck

Require exit code 0 and `CREATOR_PCK PASS: all four exact candidate hashes`. The diagnostic bypasses world creation and save handling; it reads the actual packaged resources at their runtime paths. A missing or changed candidate exits 1 with a specific failure. Do not substitute the editor or a different build. Public CI deliberately expects exit 1 with a missing-candidate diagnostic, since the private candidate binaries are not in Git.

This verifies delivered bytes, not actual character posing or native visual acceptance. Run the strict office installation smoke separately in the staged source checkout and inspect the delivered game natively. Preserve the candidate hashes, executable/PCK hashes, source revision, and test output in the creator evidence directory. No private candidate upload or release publication.
