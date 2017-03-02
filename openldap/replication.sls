{% from 'openldap/map.jinja' import openldap with context %}
{% set server_id = salt['grains.get']('ldap:server:id'', 0) %}

{% if server_id == 0 %}
fail-no-server-id:
  test.fail_without_changes:
    - name: OpenLDAP replication setup requires a non zero, unique, ldap:server:id grain to be set
{% elif not openldap.olc %}
fail-no-olc:
  test.fail_without_changes:
    - name: OpenLDAP replication setup requires an cn=config style config.  Default for debian family installs
{% else %}
openldap_formula_olc_auth:
  ldap.managed:
    - require:
      - pkg: ldap-server
      - pkg: python-ldap
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
      - "cn=config":
        - replace:
            olcServerID: "{{ server_id }}"
            olcRootPW: "{{ rootpw }}"
      - "cn=module,cn=config":
        - replace:
            olcServerID: "{{ server_id }}"
            olcRootPW: "{{ rootpw }}"

{% endif %}
  service.running:
    - name: {{ openldap.service }}
    - enable: True
