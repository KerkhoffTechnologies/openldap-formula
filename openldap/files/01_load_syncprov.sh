cat << EOFMARK | ldapadd -Y EXTERNAL -H ldapi:/// -c
dn: cn=module{1},cn=config
objectClass: olcModuleList
cn: module
olcModulePath: /usr/lib/ldap
olcModuleLoad: {0}syncprov.la
EOFMARK
