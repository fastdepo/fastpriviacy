<?php
/**
 * @var Template_VariableAccessor $VAR
 * @var array $OPT
 */
?>
<?php if ($VAR->domain->isSeoRedirectToLanding || $VAR->domain->isSeoRedirectToWww || $VAR->domain->isAliasRedirected): ?>
server {
    listen <?php echo $OPT['ipAddress']->escapedAddress . ':' . $OPT['frontendPort'] . ($OPT['ssl'] ? ' ssl' : ''); ?>;

    <?php if ($OPT['ssl']): ?>
        <?php $sslCertificate = $VAR->server->sni && $VAR->domain->physicalHosting->sslCertificate ?
            $VAR->domain->physicalHosting->sslCertificate :
            $OPT['ipAddress']->sslCertificate; ?>
        <?php if ($sslCertificate->ceFilePath): ?>
            ssl_certificate             <?php echo $sslCertificate->ceFilePath ?>;
            ssl_certificate_key         <?php echo $sslCertificate->ceFilePath ?>;
        <?php endif ?>
    <?php endif ?>

    <?php if ($VAR->domain->isSeoRedirectToLanding) : ?>
        server_name www.<?= $VAR->domain->asciiName; ?>;
    <?php elseif ($VAR->domain->isSeoRedirectToWww): ?>
        server_name <?= $VAR->domain->asciiName; ?>;
    <?php endif; ?>
    <?php if ($VAR->domain->isAliasRedirected): ?>
        <?php foreach ($VAR->domain->webAliases AS $alias): ?>
            <?php if ($alias->isSeoRedirect) : ?>
                server_name <?= $alias->asciiName; ?>;
                server_name www.<?= $alias->asciiName; ?>;
            <?php endif; ?>
        <?php endforeach; ?>
    <?php endif; ?>

    location / {
        return 301 <?= ($OPT['ssl'] ||  $VAR->domain->physicalHosting->sslRedirect)  ? 'https' : 'http'; ?>://<?php echo $VAR->domain->targetName; ?>$request_uri;
    }

    <?php if ($VAR->domain->isMailAutodiscoveryEnabled): ?>
        <?php echo $VAR->includeTemplate('domain/service/nginxMailAutoConfig.php') ?>
    <?php endif ?>
}
<?php endif; ?>

server {
    listen <?php echo $OPT['ipAddress']->escapedAddress . ':' . $OPT['frontendPort'] .
        ($OPT['default'] ? ' default_server' : '') . ($OPT['ssl'] ? ' ssl' : '') .
        ($OPT['ssl'] && $VAR->domain->physicalHosting->proxySettings['nginxHttp2'] ? ' http2' : '') ?>;

<?php if (!$VAR->domain->isSeoRedirectToWww): ?>
    server_name <?php echo $VAR->domain->asciiName ?>;
<?php endif; ?>
<?php if ($VAR->domain->isWildcard): ?>
    server_name ~^<?php echo $VAR->domain->pcreName ?>$;
<?php else: ?>
    <?php if (!$VAR->domain->isSeoRedirectToLanding) : ?>
    server_name www.<?php echo $VAR->domain->asciiName ?>;
    <?php endif; ?>
    <?php if ($OPT['ipAddress']->isIpV6()): ?>
    server_name ipv6.<?php echo $VAR->domain->asciiName ?>;
    <?php else: ?>
    server_name ipv4.<?php echo $VAR->domain->asciiName ?>;
    <?php endif ?>
<?php endif ?>
<?php if ($VAR->domain->webAliases): ?>
    <?php foreach ($VAR->domain->webAliases as $alias): ?>
    <?php if (!$alias->isSeoRedirect): ?>
    server_name <?php echo $alias->asciiName ?>;
    server_name www.<?php echo $alias->asciiName ?>;
    <?php endif;?>
    <?php endforeach ?>
<?php endif ?>
<?php if ($VAR->domain->previewDomainName): ?>
    server_name "<?php echo $VAR->domain->previewDomainName ?>";
<?php endif ?>

<?php if ($OPT['ssl']): ?>
<?php $sslCertificate = $VAR->server->sni && $VAR->domain->physicalHosting->sslCertificate ?
    $VAR->domain->physicalHosting->sslCertificate :
    $OPT['ipAddress']->sslCertificate; ?>
    <?php if ($sslCertificate->ceFilePath): ?>
    ssl_certificate             <?php echo $sslCertificate->ceFilePath ?>;
    ssl_certificate_key         <?php echo $sslCertificate->ceFilePath ?>;
    <?php endif ?>
<?php endif ?>

<?php if ($VAR->domain->physicalHosting->errordocs && !$VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
    <?= $VAR->includeTemplate('domain/service/nginxErrordocs.php'); ?>
<?php endif; ?>

<?php if (!$VAR->domain->physicalHosting->proxySettings['nginxProxyMode'] && $VAR->domain->suspended): ?>
        location / {
            return 503;
        }
    }
    <?php return ?>
<?php endif ?>

<?php if (!empty($VAR->domain->physicalHosting->proxySettings['nginxClientMaxBodySize'])): ?>
    client_max_body_size <?php echo $VAR->domain->physicalHosting->proxySettings['nginxClientMaxBodySize'] ?>;
<?php endif ?>

<?php if ($VAR->domain->physicalHosting->scriptTimeout): ?>
    proxy_read_timeout <?php echo min($VAR->domain->physicalHosting->scriptTimeout, 2147483) ?>;
<?php endif ?>

<?php if ($VAR->domain->isMailAutodiscoveryEnabled): ?>
    <?php echo $VAR->includeTemplate('domain/service/nginxMailAutoConfig.php') ?>
<?php endif ?>

<?php if (!$OPT['ssl'] && $VAR->domain->physicalHosting->sslRedirect): ?>

        location / {
            return 301 https://$host$request_uri;
        }
    }
    <?php return ?>
<?php endif ?>

    root "<?php echo $OPT['ssl'] ? $VAR->domain->physicalHosting->httpsDir : $VAR->domain->physicalHosting->httpDir ?>";
<?php if ($OPT['default']): ?>
    <?php echo $VAR->includeTemplate('service/nginxSitePreview.php') ?>
<?php endif ?>

<?php echo $VAR->domain->physicalHosting->proxySettings['allowDeny'] ?>

<?=$VAR->includeTemplate('domain/service/nginxCache.php', $OPT)?>

<?php echo $VAR->domain->physicalHosting->nginxExtensionsConfigs ?>

<?php if (!$VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
    location ~ /\.ht {
        deny all;
    }
<?php endif ?>

<?php if ($VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
    location / {
    <?php echo $VAR->includeTemplate('domain/service/proxy.php', $OPT) ?>
    }

    <?php if (!$VAR->domain->physicalHosting->proxySettings['nginxTransparentMode'] && !$VAR->domain->physicalHosting->proxySettings['nginxServeStatic']): ?>
    location /internal-nginx-static-location/ {
        alias <?php echo $OPT['documentRoot'] ?>/;
        internal;
        <?php if ($VAR->domain->physicalHosting->expires && $VAR->domain->physicalHosting->expiresStaticOnly): ?>
        expires <?=$VAR->quote($VAR->domain->physicalHosting->expires)?>;
        <?php endif ?>
    }
    <?php endif ?>
<?php endif ?>

<?php if ($VAR->domain->active && $VAR->domain->physicalHosting->hasWebstat): ?>
    <?php echo $VAR->includeTemplate('domain/service/nginxWebstatDirectories.php', $OPT) ?>
<?php endif ?>

<?php if ($VAR->domain->active): ?>
    <?php if (!$VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
        <?php echo $VAR->includeTemplate('domain/service/nginxProtectedDirectories.php', $OPT) ?>
    <?php else: ?>
        <?php echo $VAR->includeTemplate('domain/service/nginxProtectedDirectoriesProxy.php', $OPT) ?>
    <?php endif ?>
<?php endif ?>

<?php if ($VAR->domain->active && $VAR->domain->physicalHosting->proxySettings['fileSharingPrefix']
    && $VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
    location ~ "^/<?php echo $VAR->domain->physicalHosting->proxySettings['fileSharingPrefix'] ?>/" {
        <?=$VAR->includeTemplate('domain/service/proxy.php', $OPT + ['nginxCacheEnabled' => false])?>
    }
<?php endif ?>

<?php if ($VAR->domain->active && $VAR->domain->physicalHosting->proxySettings['nginxServeStatic']): ?>
    location @fallback {
        <?php if ($VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
            <?php echo $VAR->includeTemplate('domain/service/proxy.php', $OPT) ?>
        <?php else: ?>
        return 404;
        <?php endif ?>
    }

    location ~ ^/(.*\.(<?php echo $VAR->domain->physicalHosting->proxySettings['nginxStaticExtensions'] ?>))$ {
        try_files $uri @fallback;
        <?php if ($VAR->domain->physicalHosting->expires && $VAR->domain->physicalHosting->expiresStaticOnly): ?>
        expires <?=$VAR->quote($VAR->domain->physicalHosting->expires)?>;
        <?php endif ?>
    }
<?php endif ?>

<?php if ($VAR->domain->active && $VAR->domain->physicalHosting->php && $VAR->domain->physicalHosting->proxySettings['nginxServePhp']): ?>
    location ~ ^/~(.+?)(/.*?\.php)(/.*)?$ {
        <?php if ($VAR->domain->physicalHosting->scriptTimeout): ?>
        fastcgi_read_timeout <?php echo min($VAR->domain->physicalHosting->scriptTimeout, 2147483) ?>;
        <?php endif ?>
        alias <?php echo $VAR->domain->physicalHosting->webUsersDir ?>/$1/$2;
        <?php echo $VAR->includeTemplate('domain/service/fpm.php', $OPT) ?>
    }

        <?php if ($VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
    location ~ ^/~(.+?)(/.*)?$ {
            <?php echo $VAR->includeTemplate('domain/service/proxy.php', $OPT) ?>
    }
        <?php endif ?>

    location ~ \.php(/.*)?$ {
        <?php if ($VAR->domain->physicalHosting->scriptTimeout): ?>
        fastcgi_read_timeout <?php echo min($VAR->domain->physicalHosting->scriptTimeout, 2147483) ?>;
        <?php endif ?>
        <?php echo $VAR->includeTemplate('domain/service/fpm.php', $OPT) ?>
    }

        <?php if ($VAR->domain->physicalHosting->directoryIndex && !$VAR->domain->physicalHosting->proxySettings['nginxProxyMode']): ?>
    location ~ /$ {
        index <?=$VAR->quote($VAR->domain->physicalHosting->directoryIndex)?>;
    }
        <?php endif ?>
<?php endif ?>

<?php if ($VAR->domain->physicalHosting->restrictFollowSymLinks): ?>
    disable_symlinks if_not_owner from=$document_root;
<?php endif ?>

<?php if ($VAR->domain->physicalHosting->expires && !$VAR->domain->physicalHosting->expiresStaticOnly): ?>
    expires <?=$VAR->quote($VAR->domain->physicalHosting->expires)?>;
<?php endif ?>

<?php foreach ((array)$VAR->domain->physicalHosting->headers as list($name, $value)): ?>
    add_header <?=$VAR->quote([$name, $value])?>;
<?php endforeach ?>

<?php if (is_file($VAR->domain->physicalHosting->customNginxConfigFile)): ?>
    include "<?php echo $VAR->domain->physicalHosting->customNginxConfigFile ?>";
<?php endif ?>
}
