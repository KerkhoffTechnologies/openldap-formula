{% from 'openldap/map.jinja' import openldap with context %}
{% set current_path = salt['environ.get']('PATH', '/bin:/usr/bin') %}
{% set server_id = salt['grains.get']('ldap:server:id', 0) %}
{% set olc_rootdn=salt['pillar.get']('openldap:lookup:olc_rootdn', None) %}
{% set olc_rootpw=salt['pillar.get']('openldap:lookup:olc_rootpw', None) %}
{% set rootdn=salt['pillar.get']('openldap:lookup:rootdn', None) %}
{% set rootpw=salt['pillar.get']('openldap:lookup:rootpw', None) %}
{% set config_olcServerID=salt['pillar.get']('openldap:lookup:olcServerID', None) %}
{% set config_olcSyncRepl=salt['pillar.get']('openldap:lookup:config_olcSyncRepl', None) %}
{% set mdb_olcSyncRepl=salt['pillar.get']('openldap:lookup:mdb_olcSyncRepl', None) %}


{# TODO: This seems very cludge - Find a better way to represent this
         This is used to query the ldap server being configured, but 
         the connection will only success if openldap.server role is 
         already completed at precompile time #}

{% set installed_pkgs=salt['pkg.list_pkgs']() %}
{% if openldap.server_pkg in installed_pkgs %}
{% set ldap_olcSyncrepl=salt['ldap3.search']({'url': 'ldapi:///', 'bind': {'method': 'sasl', 'mechanism': 'EXTERNAL', 'dn': olc_rootdn,},}, base='cn=config', attrlist=['olcSyncrepl'],) %}
{% else %}
{% set ldap_olcSyncrepl=None %}
{% endif %}

{% if server_id == 0 %}
fail-no-server-id:
  test.fail_without_changes:
    - name: OpenLDAP replication setup requires a non zero, unique, ldap:server:id grain to be set
{% elif not openldap.olc %}
fail-no-olc:
  test.fail_without_changes:
    - name: OpenLDAP replication setup requires an cn=config style config.  Default for debian family installs
{% else %}

openldap_replication_olc_auth:
  ldap.managed:
    - connect_spec:
        url: 'ldapi:///'
        bind:
          method: sasl
          mechanism: EXTERNAL
    - entries:
      - "cn=config":
        - default:
            olcServerID: "{{ server_id }}"
        {% if server_id %}
        - replace:
            olcServerID: "{{ server_id }}"
        {% endif %}
      - "olcDatabase={0}config,cn=config":
        - default:
            olcRootDN: "cn=admin,cn=config"
        {% if olc_rootpw %}
        - replace:
            olcRootPW: "{{ olc_rootpw }}"
        {% endif %}
      - "olcDatabase={1}mdb,cn=config":
        {% if rootdn %}
        - replace:
            olcRootDN: "{{ rootdn }}"
            olcLimits: '{0}dn.exact="{{ rootdn }}" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited'
        {% endif %}
        {% if rootpw %}
        - replace:
            olcRootPW: "{{ rootpw }}"
        {% endif %}
{% endif %}
  service.running:
    - name: {{ openldap.service }}
    - enable: True

openldap_replication_olc_sync:
  ldap.managed:
    - require:
      - openldap_replication_olc_auth

    - connect_spec:
        url: 'ldapi:///'
        bind:
          method: sasl
          mechanism: EXTERNAL

    - entries:
      - "cn=config":
        - replace:
            olcServerID: {{ config_olcServerID }}

openldap_replication_olc_modules:
  cmd.script: 
    - require:
        - openldap_replication_olc_auth
    - creates: "/etc/ldap/slapd.d/cn=config/cn=module{1}.ldif"
    - source: salt://openldap/files/01_load_syncprov.sh

openldap_replication_olc_config_config:
  ldap.managed:
    - require:
      - openldap_replication_olc_modules

    - connect_spec:
        url: 'ldapi:///'
        bind:
          method: sasl
          mechanism: EXTERNAL

    - entries:
      - "olcDatabase={0}config,cn=config":

{% if ldap_olcSyncrepl
   and 'olcDatabase={0}config,cn=config' in ldap_olcSyncrepl 
   and 'olcSyncrepl' in ldap_olcSyncrepl['olcDatabase={0}config,cn=config'] 
   and ldap_olcSyncrepl['olcDatabase={0}config,cn=config']['olcSyncrepl'] != config_olcSyncRepl %}
          - replace:
              olcSyncRepl: {{ config_olcSyncRepl }}
{% elif not ldap_olcSyncrepl 
   or ('olcDatabase={0}config,cn=config' in ldap_olcSyncrepl
   and not 'olcSyncrepl' in ldap_olcSyncrepl['olcDatabase={0}config,cn=config']) %}
          - add:
              olcSyncRepl: {{ config_olcSyncRepl }}
{% endif %}
          - replace:
              olcMirrorMode: "TRUE"

openldap_replication_olc_mdb_config:
  ldap.managed:
    - require:
      - openldap_replication_olc_config_config

    - connect_spec:
        url: 'ldapi:///'
        bind:
          method: sasl
          mechanism: EXTERNAL

    - entries:
      - "olcDatabase={1}mdb,cn=config":
{% if ldap_olcSyncrepl
   and 'olcDatabase={1}mdb,cn=config' in ldap_olcSyncrepl 
   and 'olcSyncrepl' in ldap_olcSyncrepl['olcDatabase={1}mdb,cn=config']
   and ldap_olcSyncrepl['olcDatabase={1}mdb,cn=config']['olcSyncrepl'] != mdb_olcSyncRepl %}
          - replace:
              olcSyncRepl: {{ mdb_olcSyncRepl }}
{% elif not ldap_olcSyncrepl 
   or ('olcDatabase={1}mdb,cn=config' in ldap_olcSyncrepl
   and not 'olcSyncrepl' in ldap_olcSyncrepl['olcDatabase={1}mdb,cn=config']) %}
          - add:
              olcSyncRepl: {{ mdb_olcSyncRepl }}
{% endif %}
          - replace:
              olcMirrorMode: "TRUE"
