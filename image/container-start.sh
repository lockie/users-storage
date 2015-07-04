#!/bin/bash
set -e

# database is uninitialized
if [ ! -e /etc/ldap/docker_bootstrapped ]; then
	cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
slapd slapd/backend string HDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

	dpkg-reconfigure -f noninteractive slapd

	DC1=`echo ${LDAP_DOMAIN} | awk -F. '{ print $1 }'`
	DC2=`echo ${LDAP_DOMAIN} | awk -F. '{ print $2 }'`
	sed -i "s/admins: cn=Manager,dc=my-domain,dc=com/admins: cn=admin,dc=${DC1},dc=${DC2}/" /var/lib/ldap-account-manager/config/lam.conf
	sed -i "s/dc=my-domain,dc=com/dc=${DC1},dc=${DC2}/g" /var/lib/ldap-account-manager/config/lam.conf
	sed -i "s/treesuffix: dc=yourdomain,dc=org/treesuffix: dc=${DC1},dc=${DC2}/" /var/lib/ldap-account-manager/config/lam.conf
	# do not manage groups, hosts & samba stuff
	sed -i "s/activeTypes: user,group,host,smbDomain/activeTypes: user/" /var/lib/ldap-account-manager/config/lam.conf
	# ignore POSIX
	sed -i "s/types: modules_user: inetOrgPerson,posixAccount,shadowAccount,sambaSamAccount/types: modules_user: inetOrgPerson/" /var/lib/ldap-account-manager/config/lam.conf

	# fix file permissions
	chown -R openldap:openldap /var/lib/ldap/
	chown -R www-data:www-data /var/lib/nginx

	echo 1 > /etc/ldap/docker_bootstrapped
fi

