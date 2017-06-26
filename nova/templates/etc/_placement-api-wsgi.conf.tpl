Listen 0.0.0.0:{{ .Values.network.placement.port }}

<VirtualHost *:{{ .Values.network.placement.port }}>
    WSGIDaemonProcess placement-api processes=1 threads=1 user=nova group=nova display-name=%{GROUP} python-path=/var/lib/kolla/venv/lib/python2.7/site-packages
    WSGIProcessGroup placement-api
    WSGIScriptAlias / /var/lib/kolla/venv/bin/nova-placement-api
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog "/var/log/placement-api.log"
    LogFormat "%{X-Forwarded-For}i %l %u %t \"%r\" %>s %b %D \"%{Referer}i\" \"%{User-Agent}i\"" logformat
    CustomLog "/var/log/nova/placement-api-access.log" logformat
    <Directory /var/lib/kolla/venv/bin>
        <Files nova-placement-api>
            Require all granted
        </Files>
    </Directory>
</VirtualHost>
