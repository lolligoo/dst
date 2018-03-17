#
#!/bin/bash
#
source "configure.sh"
source "myfunc.sh"

if master; then startserver "Master"; fi
if caves; then startserver "Caves"; fi
