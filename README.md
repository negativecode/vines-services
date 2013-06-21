# Welcome to Vines Services

Vines Services are dynamically updated groups of systems based on criteria like
hostname, installed software, operating system, etc. Send a command to the
service and it runs on every system in the group. Services, files and permissions
are managed via the bundled web application.

Services are defined using VinesQL, a simple query language that finds systems
based on their machine attributes. A "Mac OS X Lion" service might be
defined as: platform is 'mac_os_x' and platform_version starts with '10.7'.
As machines update to Lion, they will join this service automatically and may
be managed as one group.

Additional documentation can be found at www.getvines.org.

## Usage

```
$ gem install vines-services
$ vines-services init wonderland.lit
$ cd wonderland.lit && vines-services start
```

## Dependencies

Vines Services requires Ruby 1.9.3 or better. Instructions for installing the
needed OS packages, as well as Ruby itself, are available at
http://www.getvines.org/ruby.

## Development

```
$ script/bootstrap
$ script/tests
```

## Contact

* David Graham <david@negativecode.com>

## License

Vines Services is released under the MIT license. Check the LICENSE file for details.
