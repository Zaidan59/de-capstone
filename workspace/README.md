# Shared local workspace

Open this directory in **VSCodium**: `/config/workspace`.

This workspace is mapped to `./workspace` on Windows/Linux hosts. Files edited
through the browser desktop are therefore available to the host's normal tools.

## Tool checks inside a workbench terminal

```bash
python --version
java -version
javac -version
mvn --version
git --version
codium --version
ls /opt/hop/hop-gui.sh
```

VSCodium is a desktop editor streamed by Webtop over HTTPS. It is **not**
code-server and is **not** a web-native VS Code fork. The Apache Hop GUI is
available in the same XFCE desktop via Applications > Development > Apache Hop
GUI, or with `hop-gui` from a terminal.

Open the sample Hop project at `/config/workspace/hop-project`.
