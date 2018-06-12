#!/bin/bash
# author: Stefan Moll <stefan@stefaus.de>
cd $SAROSPATH

if [ $HOSTNAME == "saros-alice" ]; then
    IP=192.168.25.100
    PORT=12345
    NAME=alice
    SFTNAME=Alice
elif [ $HOSTNAME == "saros-bob" ]; then
    IP=192.168.25.101
    PORT=12346
    NAME=bob
    SFTNAME=Bob
elif [ $HOSTNAME == "saros-carl" ]; then
    IP=192.168.25.102
    PORT=12347
    NAME=carl
    SFTNAME=Carl
elif [ $HOSTNAME == "saros-dave" ]; then
    IP=192.168.25.103
    PORT=12348
    NAME=dave
    SFTNAME=Dave
else 
    echo "unexpected hostname, exiting"
    exit 1
fi


jdk/bin/java \
   -Xmx512m \
   -ea \
   -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=6006 \
   -Dcom.sun.management.jmxremote.rmi.port=9090 \
   -Dcom.sun.management.jmxremote=true \
   -Dcom.sun.management.jmxremote.port=9090 \
   -Dcom.sun.management.jmxremote.ssl=false \
   -Dcom.sun.management.jmxremote.authenticate=false \
   -Dcom.sun.management.jmxremote.local.only=false \
   -Djava.rmi.server.hostname=$IP \
   -XX:+UnlockCommercialFeatures -XX:+FlightRecorder \
   -XX:MaxPermSize=256m \
   -Djava.security.manager \
   -Djava.security.policy=file:git/saros/de.fu_berlin.inf.dpp/test/resources/stf/all.policy \
   -Dde.fu_berlin.inf.dpp.debug=true \
   -Dde.fu_berlin.inf.dpp.testmode=$PORT \
   -Dde.fu_berlin.inf.dpp.sleepTime=200 \
   -Djava.rmi.server.hostname=localhost \
   -Dorg.eclipse.swtbot.keyboard.strategy=org.eclipse.swtbot.swt.finder.keyboard.MockKeyboardStrategy \
   -Dorg.eclipse.swtbot.keyboard.layout=de.fu_berlin.inf.dpp.stf.server.bot.default \
   -Duser.language=en \
   -Duser.country=US \
   -Dfile.encoding=UTF-8 \
   -Djava.util.Arrays.useLegacyMergeSort=true \
   -Declipse.pde.launch=true \
   -classpath eclipse/plugins/org.eclipse.equinox.launcher_1.2.0.v20110502.jar org.eclipse.equinox.launcher.Main \
   -launcher eclipse/eclipse \
   -name Eclipse \
   -showsplash 600 \
   -product org.eclipse.platform.ide \
   -data workspaces/main/../workspace-$NAME-stf \
   -configuration file:workspaces/main/.metadata/.plugins/org.eclipse.pde.core/Saros_STF_$SFTNAME/ \
   -dev file:workspaces/main/.metadata/.plugins/org.eclipse.pde.core/Saros_STF_$SFTNAME/dev.properties \
   -os linux \
   -ws gtk \
   -arch x86_64 \
   -nl en_US 

