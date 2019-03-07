require_relative "../../../synced_folders/unix_mount_helpers"

module VagrantPlugins
  module GuestFreeBSD
    module Cap
      class MountVirtualBoxSharedFolder
        extend SyncedFolder::UnixMountHelpers

        def self.mount_virtualbox_shared_folder(machine, name, guestpath, options)
          guest_path = Shellwords.escape(guestpath)

          addon_mount_type = "-t vboxvfs"

          mount_options = options.fetch(:mount_options, [])
          detected_ids = detect_owner_group_ids(machine, guest_path, mount_options, options)
          mount_uid = detected_ids[:uid]
          mount_gid = detected_ids[:gid]

          mount_options << "uid=#{mount_uid}"
          mount_options << "gid=#{mount_gid}"
          mount_options = mount_options.join(',')
          mount_command = "mount #{addon_mount_type} -o #{mount_options} #{name} #{guest_path}"

          # Ensure the module is loaded
          machine.communicate.sudo("kldload -n vboxvfs")

          # Create the guest path if it doesn't exist
          machine.communicate.sudo("mkdir -p #{guest_path}")

          stderr = ""
          result = machine.communicate.sudo(mount_command, error_check: false) do |type, data|
            stderr << data if type == :stderr
          end

          # Chown the directory to the proper user. We skip this if the
          # mount options contained a readonly flag, because it won't work.
          if !options[:mount_options] || !options[:mount_options].include?("ro")
            chown_command = "chown #{mount_uid}:#{mount_gid} #{guest_path}"
            machine.communicate.sudo(chown_command)
          end

          emit_upstart_notification(machine, guest_path)
        end

        def self.unmount_virtualbox_shared_folder(machine, guestpath, options)
          guest_path = Shellwords.escape(guestpath)

          result = machine.communicate.sudo("umount #{guest_path}", error_check: false)
          if result == 0
            machine.communicate.sudo("rmdir #{guest_path}", error_check: false)
          end
        end
      end
    end
  end
end
