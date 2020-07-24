<?php
/**
 * @var Template_VariableAccessor $VAR
 * @var array $OPT
 */
?>
server {
    listen <?php echo $OPT['ipAddress']->escapedAddress . ':' . $OPT['frontendPort'] .
        ($OPT['default'] ? ' default_server' : '') . ($OPT['ssl'] ? ' ssl' : '') ?>;

    server_name <?php echo $VAR->domain->asciiName ?>;
<?php if ($VAR->domain->isWildcard): ?>
    server_name <?php echo $VAR->domain->wildcardName ?>;
<?php else: ?>
    server_name www.<?php echo $VAR->domain->asciiName ?>;
<?php endif ?>
<?php if (!$VAR->domain->isWildcard): ?>
<?php   if ($OPT['ipAddress']->isIpV6()): ?>
    server_name ipv6.<?php echo $VAR->domain->asciiName ?>;
<?php   else: ?>
    server_name ipv4.<?php echo $VAR->domain->asciiName ?>;
<?php   endif ?>
<?php endif ?>

<?php foreach ($VAR->domain->webAliases as $alias): ?>
    server_name <?php echo  $alias->asciiName ?>;
    server_name www.<?php echo $alias->asciiName ?>;
    <?php if ($OPT['ipAddress']->isIpV6()): ?>
    server_name ipv6.<?php echo $alias->asciiName ?>;
    <?php else: ?>
    server_name ipv4.<?php echo $alias->asciiName ?>;
    <?php endif ?>
<?php endforeach ?>

<?php if ($OPT['ssl']): ?>
    <?php $sslCertificate = $VAR->server->sni && $VAR->domain->forwarding->sslCertificate ?
        $VAR->domain->forwarding->sslCertificate :
        $OPT['ipAddress']->sslCertificate; ?>
    <?php if ($sslCertificate->ceFilePath): ?>
        ssl_certificate             <?php echo $sslCertificate->ceFilePath ?>;
        ssl_certificate_key         <?php echo $sslCertificate->ceFilePath ?>;
    <?php endif ?>
<?php endif ?>

<?php if (!$OPT['ssl'] && $VAR->domain->forwarding->sslRedirect): ?>
        location / {
            return 301 https://$host$request_uri;
        }
    }
    <?php return ?>
<?php endif ?>

<?php if ($OPT['default']): ?>
<?php echo $VAR->includeTemplate('service/nginxSitePreview.php') ?>
<?php endif ?>

    <?php echo $VAR->domain->forwarding->nginxExtensionsConfigs ?>

    location / {
    <?php if ($OPT['ssl']): ?>
        proxy_pass https://127.0.0.1:<?php echo $OPT['backendPort'] ?>;
    <?php else: ?>
        proxy_pass http://127.0.0.1:<?php echo $OPT['backendPort'] ?>;
    <?php endif ?>
        proxy_set_header Host 			 $host;
        proxy_set_header X-Real-IP 		 $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        access_log off;
    }

}
