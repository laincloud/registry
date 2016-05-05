# Lain Registry

## 组件描述
Lain Registry 组件在 Lain 中主要用于 Image 存储，集群中所以的 Image 都由 Lain Registry 组件提供。组件目前使用的 Registry 的版本为 V2.0.1，计划升级到 V2.3.1，关于 Registry 的官方具体描述可以参见[这里](https://github.com/docker/distribution)。

Lain Registry 组件在官方 Registry 版本的基础上进行了 Lain 化。运维人员可以在 etcd 中进行一些配置，以更新 Registry 相应的设置，包括后段存储、Auth设置等。Lain Registry 组件默认使用本地磁盘作为存储后端，默认不使用 Auth。

## 组件顶层设计

Lain Registry 仓库地址为： `http://laingit.bdp.cc/lain/registry.git`

Lain Registry 的组件架构图如下所示：

![Lain Registry 架构图](registry.png)

Lain Registry 采用的 Base Image 为使用官方 Registry V2.0.1 构建好的 Image，在启动 Lain Registry Container 时，会从 etcd 中读取一些配置，然后以这些配置为基础结合提供的 config.yml 文件运行 Registry。

默认情况下组件会将 Image 存放在本地磁盘的 `/var/lib/registry` 目录下，也可以通过配置 moosfs 来实现集群分布式存储；

默认情况下组件不开启 Auth，但是 Lain 中也提供了 Registry 的 auth server，即 Lain Console，可以在 etcd 中设置相应的 Auth 信息，Lain 中使用的 Registry Auth 方式遵照官方实现，具体可以参见[这里](https://docs.docker.com/registry/spec/auth/token/)


## 使用方法
### Auth 设置
集群中由 Lain Console 作为 Lain Registry 的 auth server，API为`api/v1/authorize/registry/`

1. Open Auth 

- 首先在 etcd 中设置：` etcdctl set /lain/config/auth/registry '{"realm":"http://console.<domain>/api/v1/authorize/registry/", "issuer":"auth server", "service":"<domain>"}'`
    
    其中的参数对应如下，详细介绍可以参考[这里](https://docs.docker.com/registry/configuration/#token)：
    
    > realm： 提供 registry auth 的地址
    
    > issuer： auth server 与 registry 之间约定的 issuer
    
    > service： 在 Lain 中设置为当前集群域名

- 重启 registry 容器

2. Close Auth
- `etcdctl rm /lain/config/auth/registry`
- 重启 registry 容器


### 储存后端设置


```
对于storage配置的修改需要进行如下操作：
1. docker-enter registry container; 修改对应的config.yaml
2. 重启registry
```
#### 注意事项

```
当config.yaml有问题时，重启时registry无法正常启动，需要进行如下操作：
1. docker rm registry。
2. 等待deploy重新拉起registry再进行修改，
在修改config.yaml时，最好先测试然后再重启registry。
```

1 对于S3支持：

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
      regionendpoint: http://s3.bdp.svc #optional endpoints 
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

2 对于OSS支持：

```
storage:
    oss:
        accesskeyid: ABCDEFGHIJ0123456789 #accesskeyid
        accesskeysecret: AB12C3dE4fGhIvmMB4TZrpypR0rOJ2G5WhGUPn9L #accesskeysecret
        region: oss-cn-beijing #OSS region name
        endpoint: http://s3.bdp.svc #optional endpoints
        internal: optional internal endpoint
        bucket: test #OSS bucket
        encrypt: false #optional data encryption setting
        secure: false #optional ssl setting
        chunksize: 5242880 #optional size valye
        rootdirectory: /registry #optional root directory
```

### 清理设置
1 配置方案

```
storage:
  delete:
    enabled: true
compatibility: # see issue https://github.com/docker/distribution/issues/1661
  schema1:
    disablesignaturestore: true
```

2 清理方式

```
1. curl -X DELETE /v2/{repo}/manifests/{digest} # 调用registry api 删除指定digest的image
2. registry garbage-collect config.yaml # 在registry节点清理被标记删除的layer及manifest
```

#### 注意事项
```
registry 清理最好是在read-only状态下进行清理工作，也就是在gc的时候不要push image
```