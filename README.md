# LAIN Registry

[![Build Status](https://travis-ci.org/laincloud/registry.svg?branch=master)](https://travis-ci.org/laincloud/registry)
[![MIT license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://opensource.org/licenses/MIT)

## 组件描述
LAIN Registry 组件在 LAIN 中主要用于镜像存储，集群中所有的镜像都由 LAIN Registry 组件提供及存储。关于 Registry 的官方具体描述可以参见[这里](https://github.com/docker/distribution)。

LAIN Registry 组件在 Docker Registry 版本的基础上进行了 LAIN 化。SA 可以在 etcd 中进行一些配置，以更新 Registry 相应的设置，包括后端存储、Auth设置等。LAIN Registry 组件默认使用本地磁盘作为存储后端，默认不使用 Auth。

## 组件顶层设计

LAIN Registry 的组件架构图如下所示：

![LAIN Registry 架构图](registry.png)

在启动 LAIN Registry Container 时，会从 etcd 中读取一些配置，然后以这些配置为基础结合提供的 config.yml 文件运行 Registry。

默认情况下组件会将镜像存放在本地磁盘的 `/var/lib/registry` 目录下(LAIN bootstrap 时设置)，也可以通过配置 moosfs 等来实现集群分布式存储；

默认情况下组件不开启 Auth，但是 LAIN 中也提供了 Registry 的 auth server，即 LAIN Console，可以在 etcd 中设置相应的 Auth 信息，LAIN 中使用的 Registry Auth 方式遵照官方实现，具体可以参见[这里](https://docs.docker.com/registry/spec/auth/token/)


## 使用方法
### Auth 设置
集群中由 LAIN Console 作为 LAIN Registry 的 auth server，API为`api/v1/authorize/registry/`

#### Open Auth 

- 首先在 etcd 中设置：` etcdctl set /lain/config/auth/registry '{"realm":"http://console.<domain>/api/v1/authorize/registry/", "issuer":"auth server", "service":"<domain>"}'`

    其中的参数对应如下，详细介绍可以参考[这里](https://docs.docker.com/registry/configuration/#token)：
    
    > realm： 提供 registry auth 的地址
    
    > issuer： auth server 与 registry 之间约定的 issuer
    
    > service： 在 LAIN 中设置为当前集群域名

- 重启 registry 容器

#### Close Auth

- `etcdctl rm /lain/config/auth/registry`

- 重启 registry 容器


### 储存后端设置

对于storage配置的修改需要进行如下操作：

1. docker-enter registry container; 修改对应的config.yaml；

2. 重启registry

#### 对于S3支持：

```
#Example:
version: 0.1
log:
  level: debug
  fields:
    service: registry
    environment: development
storage:
    cache:
        layerinfo: inmemory
    s3:
      accesskey: ABCDEFGHIJ0123456789
      secretkey: AB12C3dE4fGhIvmMB4TZrpypR0rOJ2G5WhGUPn9L
      region: us-west-1 #important if use amazon filesystem
      regionendpoint: http://s3.domain.svc #optional endpoints 
      bucket: test
      secure: true
      v4auth: true
      chunksize: 5242880
      rootdirectory: /registry
    maintenance:
        uploadpurging:
            enabled: false
http:
    addr: :5000
    secret: asecretforlocaldevelopment
auth:
  token:
      realm: https://console.domain/api/v1/authorize/registry/
      issuer: "auth server"
      service: "lain.local"
      rootcertbundle: /lain/app/auth/server.pem
```

#### 对于OSS支持：

```
storage:
    oss:
        accesskeyid: ABCDEFGHIJ0123456789 #accesskeyid
        accesskeysecret: AB12C3dE4fGhIvmMB4TZrpypR0rOJ2G5WhGUPn9L #accesskeysecret
        region: oss-cn-beijing #OSS region name
        endpoint: http://s3.domain.svc #optional endpoints
        internal: optional internal endpoint
        bucket: test #OSS bucket
        encrypt: false #optional data encryption setting
        secure: false #optional ssl setting
        chunksize: 5242880 #optional size valye
        rootdirectory: /registry #optional root directory
```

#### 注意事项:

当config.yaml有问题时，重启时registry无法正常启动，需要进行如下操作：

1. docker rm registry；

2. 等待deploy重新拉起registry再进行修改

在修改config.yaml时，最好先测试然后再重启registry。


### 清理设置

#### 配置方案：

```
storage:
  delete:
    enabled: true
compatibility: # see issue https://github.com/docker/distribution/issues/1661
  schema1:
    disablesignaturestore: true
```

#### 清理方式：

- curl -X DELETE /v2/{repo}/manifests/{digest} # 调用registry api 删除指定digest的image
- registry garbage-collect config.yaml # 在registry节点清理被标记删除的layer及manifest


#### 注意事项：

registry 清理最好是在 read-only 状态下进行清理工作，也就是在 gc 的时候不要 push image
