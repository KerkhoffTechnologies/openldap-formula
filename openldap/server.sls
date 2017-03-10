{% from 'openldap/map.jinja' import openldap with context %}
{% set olc_rootdn=salt['pillar.get']('openldap:lookup:olc_rootdn', None) %}
{% set olc_rootpw=salt['pillar.get']('openldap:lookup:olc_rootpw', None) %}
{% set rootdn=salt['pillar.get']('openldap:lookup:rootdn', None) %}
{% set rootpw=salt['pillar.get']('openldap:lookup:rootpw', None) %}

python-ldap:
  pkg.installed:
    - name: {{ openldap.python_ldap_package }}

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
      - "olcDatabase={0}config,cn=config":
        - default:
            olcRootDN: "{{ olc_rootdn }}"
        {% if olc_rootpw %}
        - replace:
            olcRootPW: "{{ olc_rootpw }}"
        {% endif %}
      - "olcDatabase={1}mdb,cn=config":
        {% if olc_rootpw %}
        - replace:
            olcRootDN: "{{ rootdn }}"
            olcRootPW: "{{ rootpw }}"
        {% endif %}

{% endif %}
  service.running:
    - name: {{ openldap.service }}
    - enable: True
