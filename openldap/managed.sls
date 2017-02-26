#Iterate through pillar stored 'entries' for ldap.managed runs
{% from 'openldap/map.jinja' import openldap with context %}

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
{% endif %}
  service.running:
    - name: {{ openldap.service }}
    - enable: True
