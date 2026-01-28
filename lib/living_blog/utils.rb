module LivingBlog
    module Utils
        def sh!(cmd)
            puts "+ #{cmd}"
            ok = system(cmd)
            raise Error, "Command failed: #{cmd}" unless ok
        end
    end
    
    # Make it available as a module method
    def self.sh!(cmd)
        puts "+ #{cmd}"
        ok = system(cmd)
        raise Error, "Command failed: #{cmd}" unless ok
    end
end