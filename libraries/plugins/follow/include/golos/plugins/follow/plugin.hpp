#pragma once

#include <golos/plugins/chain/plugin.hpp>
#include <golos/plugins/json_rpc/utility.hpp>
#include "follow_api_object.hpp"

namespace golos {
    namespace plugins {
        namespace follow {
            using json_rpc::msg_pack;

            ///               API,                          args,       return
            DEFINE_API_ARGS(get_followers, msg_pack, get_followers_r)
            DEFINE_API_ARGS(get_following, msg_pack, get_following_r)
            DEFINE_API_ARGS(get_follow_count, msg_pack, get_follow_count_r)
            DEFINE_API_ARGS(get_feed_entries, msg_pack, get_feed_entries_r)
            DEFINE_API_ARGS(get_feed, msg_pack, get_feed_r)
            DEFINE_API_ARGS(get_blog_entries, msg_pack, get_blog_entries_r)
            DEFINE_API_ARGS(get_blog, msg_pack, get_blog_r)
            DEFINE_API_ARGS(get_account_reputations, msg_pack, get_account_reputations_r)
            DEFINE_API_ARGS(get_reblogged_by, msg_pack, get_reblogged_by_r)
            DEFINE_API_ARGS(get_blog_authors, msg_pack, get_blog_authors_r)

            class plugin final : public appbase::plugin<plugin> {
            public:

                constexpr static const char *plugin_name = "follow";

                APPBASE_PLUGIN_REQUIRES((chain::plugin))

                static const std::string &name() {
                    static std::string name = plugin_name;
                    return name;
                }

                DECLARE_API (
                        (get_followers)
                        (get_following)
                        (get_follow_count)
                        (get_feed_entries)
                        (get_feed)
                        (get_blog_entries)
                        (get_blog)
                        (get_account_reputations)
                                ///Gets list of accounts that have reblogged a particular post
                        (get_reblogged_by)
                                /// Gets a list of authors that have had their content reblogged on a given blog account
                        (get_blog_authors))

                get_account_reputations_r get_account_reputations_native(const get_account_reputations_a &);

                plugin();

                void set_program_options(boost::program_options::options_description &cli,
                                         boost::program_options::options_description &cfg) override;

                void plugin_initialize(const boost::program_options::variables_map &options) override;

                uint32_t max_feed_size();

                void plugin_startup() override;

                void plugin_shutdown() override {}

                ~plugin();

            private:
                struct impl;
                std::unique_ptr<impl> pimpl;
            };

        }
    }
} //golos::follow