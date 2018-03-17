#
#!/bin/bash
#
source "$HOME/dst/shell/configure.sh"
source "$HOME/dst/shell/myfunc.sh"

if master; then startserver "Master"; fi
if caves; then startserver "Caves"; fi
