# Домашнее задание к занятию "13.2 разделы и монтирование"
Приложение запущено и работает, но время от времени появляется необходимость передавать между бекендами данные. А сам бекенд генерирует статику для фронта. Нужно оптимизировать это.
Для настройки NFS сервера можно воспользоваться следующей инструкцией (производить под пользователем на сервере, у которого есть доступ до kubectl):
* установить helm: curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
* добавить репозиторий чартов: helm repo add stable https://charts.helm.sh/stable && helm repo update
* установить nfs-server через helm: helm install nfs-server stable/nfs-server-provisioner

В конце установки будет выдан пример создания PVC для этого сервера.

## Задание 1: подключить для тестового конфига общую папку
В stage окружении часто возникает необходимость отдавать статику бекенда сразу фронтом. Проще всего сделать это через общую папку. Требования:
* в поде подключена общая папка между контейнерами (например, /static);
* после записи чего-либо в контейнере с беком файлы можно получить из контейнера с фронтом.

    * Подготовим манифест для [пода](13-kubernetes-config/13.2/pod.yaml)
    * Проверим работу пода и общих _volumeMounts_

```shell
$ kubectl get po -o wide
NAME       READY   STATUS    RESTARTS   AGE     IP            NODE    NOMINATED NODE   READINESS GATES
test-pod   2/2     Running   0          3m43s   10.233.71.2   node3   <none>           <none>

$ kubectl.exe exec -c busybox test-pod -- sh -c "echo '123' > /tmp/cache/some.txt"

$ kubectl.exe exec -c busybox test-pod -- sh -c "echo '123' > /tmp/cache/some.txt"
```

  * Как видно из вывода консоли, мы создали файл в одном контейнере и файл стал доступен из другого. ВСЕ РАБОТАЕТ!

## Задание 2: подключить общую папку для прода
Поработав на stage, доработки нужно отправить на прод. В продуктиве у нас контейнеры крутятся в разных подах, поэтому потребуется PV и связь через PVC. Сам PV должен быть связан с NFS сервером. Требования:
* все бекенды подключаются к одному PV в режиме ReadWriteMany;
* фронтенды тоже подключаются к этому же PV с таким же режимом;
* файлы, созданные бекендом, должны быть доступны фронту.

  * Подготовим манифесты для [stage](13-kubernetes-config/13.2/pod1-nfs.yaml), [prod](13-kubernetes-config/13.2/pod2-nfs.yaml) и для [_PVC_](13-kubernetes-config/13.2/pvc.yaml) (не забываем установить nfs-server через helm и добавить на хосты драйвера nfs при помощи установки пакета nfs-common на рабочие ноды)
  * Запустим поды и проверим, что все работает

```shell
$ kubectl.exe apply -f 13-kubernetes-config/13.2/pod1-nfs.yaml
pod/pod1-nfs created

$ kubectl.exe apply -f 13-kubernetes-config/13.2/pod2-nfs.yaml
pod/pod2-nfs created

$ kubectl.exe apply -f pvc.yaml 
persistentvolumeclaim/pvc created

$ kubectl.exe get po
NAME                                  READY   STATUS    RESTARTS   AGE                            
nfs-server-nfs-server-provisioner-0   1/1     Running   0          23m                            
pod1-nfs                              1/1     Running   0          8m54s                          
pod2-nfs                              1/1     Running   0          5m31s                          

$ kubectl.exe get pvc
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE  
pvc    Bound    pvc-cb2503a1-8518-44b3-9bb4-678b69434907   1Gi        RWO            nfs            7m58s
                                                                                                         
$ kubectl.exe get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM         STORAGECLASS   REASON   AGE  
pvc-cb2503a1-8518-44b3-9bb4-678b69434907   1Gi        RWO            Delete           Bound    default/pvc   nfs                     7m59s
```

  * Поды, _PVC_ и _PV_ созданы, проверим работу шары!
  * Записываем в файл одного пода и читаем его из другого пода:

```shell
$ kubectl.exe exec -c nginx pod1-nfs -- sh -c "echo 'THIS IS SPARTA\!\!\!' > /static/test.txt"

$ kubectl.exe exec -c nginx pod2-nfs -- sh -c "cat /static/test.txt"
THIS IS SPARTA\!\!\!
```

  * Файл добавленный на одном поде доступен на другом, ВСЕ РАБОТАЕТ!

---
### Как оформить ДЗ?

Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории.

---
