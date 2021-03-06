##
# KUSANAGI WordPres Deployment for kusanagi-docker
# (C)2019 Prime-Strategy Co,Ltd
# Licenced by GNU GPL v2
#

source .kusanagi
source $LIBDIR/image_versions

IMAGE=$([ $OPT_NGINX ] && echo $KUSANAGI_NGINX_IMAGE || ([ $OPT_HTTPD ] && echo $KUSANAGI_HTTPD_IMAGE))
# create docker-compose.yml
env FQDN=$FQDN \
    PROFILE=$PROFILE \
    HTTPD_IMAGE=$IMAGE \
    KUSANAGI_PHP_IMAGE=$KUSANAGI_PHP_IMAGE \
    CONFIG_IMAGE=$KUSANAGI_CONFIG_IMAGE \
    CERTBOT_IMAGE=$CERTBOT_IMAGE \
    HTTP_PORT=$HTTP_PORT \
    HTTP_TLS_PORT=$HTTP_TLS_PORT \
    DBLIB=$DBLIB \
	envsubst '$$FQDN $$PROFILE $$HTTPD_IMAGE
	$$KUSANAGI_PHP_IMAGE
	$$CONFIG_IMAGE $$CERTBOT_IMAGE
	$$HTTP_PORT $$HTTP_TLS_PORT $$DBLIB' \
	< <(cat $LIBDIR/templates/docker.template $LIBDIR/templates/config.template $LIBDIR/templates/php.template) > docker-compose.yml
if ! [ $NO_USE_DB ] ; then
	case "$KUSANAGI_DB_SYSTEM" in
	mysql)
		env PROFILE=$PROFILE KUSANAGI_MYSQL_IMAGE=$KUSANAGI_MYSQL_IMAGE \
		envsubst '$$PROFILE $$KUSANAGI_MYSQL_IMAGE' \
		< $LIBDIR/templates/mysql.template >> docker-compose.yml
		;;
	pgsql)
		env PROFILE=$PROFILE POSTGRESQL_IMAGE=$POSTGRESQL_IMAGE \
		envsubst '$$PROFILE $$POSTGRESQL_IMAGE' \
		< $LIBDIR/templates/pgsql.template >> docker-compose.yml
		;;
	esac

fi
echo >> docker-compose.yml
echo 'volumes:' >> docker-compose.yml
echo '  kusanagi:' >>  docker-compose.yml
[[ $DBHOST =~ ^localhost ]] && echo '  database:' >> docker-compose.yml


k_compose up -d \
&& k_configcmd_root "/" chown 1000:1001 /home/kusanagi \
&& k_configcmd "/" chmod 751 /home/kusanagi \
&& k_configcmd "/" mkdir -p $DOCUMENTROOT \
&& tar cf - -C $LIBDIR/drupal drupal.sh | k_configcmd $BASEDIR tar xf - 

k_print_green "$(eval_gettext 'Provision Drupal')"

if [ "x$TARPATH" != "x" ] && [ -f $TARPATH ] ; then
	mkdir contents
	tar xf $TARPATH -C contents 
	tar cf - -C contents . | k_configcmd $DOCUMENTROOT tar xf - 
elif [  "x$GITPATH" != "x" ] && [ -f $GITPATH ] ; then 
	mkdir contents
	git clone $GITPATH ./contents
	tar cf - -C contents . | k_configcmd $DOCUMENTROOT tar xf - 
else
	k_configcmd $BASEDIR sh ./drupal.sh $DRUPAL_VERSION \
	&& sleep 1 \
	&& k_configcmd $BASEDIR rm ./drupal.sh 
fi

