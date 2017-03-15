{% from 'openldap/map.jinja' import openldap with context %}
{% set olc_rootdn=salt['pillar.get']('openldap:lookup:olc_rootdn', None) %}
{% set olc_rootpw=salt['pillar.get']('openldap:lookup:olc_rootpw', None) %}
{% set rootdn=salt['pillar.get']('openldap:lookup:rootdn', None) %}
{% set rootpw=salt['pillar.get']('openldap:lookup:rootpw', None) %}
{% set server_id = salt['grains.get']('ldap:server:id', 0) %}

python-ldap:
  pkg.installed:
    - name: {{ openldap.python_ldap_package }}

ldap-client:
  pkg.installed:
    - name: {{ openldap.client_pkg }}
  file.managed:
    - name: {{ openldap.client_config }}
    - source: salt://openldap/files/ldap.conf
    - template: jinja
    - user: root
    - group: {{ openldap.su_group }}
    - mode: 644
    - makedirs: True
    - require:
      - pkg: ldap-client

ldap-server:
  pkg.installed:
    - name: {{ openldap.server_pkg }}
{% if not openldap.olc %}
  file.managed:
    - name: {{ openldap.server_config }}
    - source: salt://openldap/files/slapd.conf
    - template: jinja
    - user: root
    - group: {{ openldap.su_group }}
    - mode: 644
    - makedirs: True
    - require:
      - pkg: ldap-server
      - pkg: python-ldap
{% else %}
openldap_formula_olc_auth:
  ldap.managed:
    - connect_spec:
        url: 'ldapi:///'
        bind:
          method: sasl
          mechanism: EXTERNAL
    - entries:
      - "cn=config":
        - default:
            olcServerID: 1
        {% if server_id %}
        - replace:
            olcServerID: "{{ server_id }}"
        {% endif %}
      - "olcDatabase={0}config,cn=config":
        - default:
            olcRootDN: "{{ olc_rootdn }}"
        {% if olc_rootpw %}
        - replace:
            olcRootPW: "{{ olc_rootpw }}"
        {% endif %}
      - "olcDatabase={1}mdb,cn=config":
        {% if rootdn %}
        - replace:
            olcRootDN: "{{ rootdn }}"
            olcLimits: dn.exact="{{ rootdn }}" time.soft=unlimited time.hard=unlimited size.soft=unlimited size.hard=unlimited
        {% endif %}
        {% if rootpw %}
        - replace:
            olcRootPW: "{{ rootpw }}"
        {% endif %}

{% endif %}
  service.running:
    - name: {{ openldap.service }}
    - enable: True

ldap-defaults:
  file.managed:
    - name: /etc/default/slapd
    - source: salt://openldap/files/defaults
    - template: jinja
    - user: root
    - group: {{ openldap.su_group }}
    - mode: 644
    - makedirs: True
    - require:
      - pkg: ldap-server
      - pkg: python-ldap
      - pkg: ldap-client
