import {
  FeedConfigGenerator,
  FeedConfigName,
  FeedResponse,
  FeedVersion,
  IFeedClient,
} from './types';
import { Context } from '../../Context';
import { CachedFeedClient, FeedClient } from './clients';
import { ioRedisPool } from '../../redis';
import {
  FeedPreferencesConfigGenerator,
  FeedUserStateConfigGenerator,
  SimpleFeedConfigGenerator,
} from './configs';
import { SnotraClient } from '../snotra';

/**
 * Utility class for easily generating feeds using provided config and client
 */
export class FeedGenerator {
  private readonly client: IFeedClient;
  private readonly config: FeedConfigGenerator;
  private readonly feedId?: string;

  constructor(
    client: IFeedClient,
    config: FeedConfigGenerator,
    feedId?: string,
  ) {
    this.client = client;
    this.config = config;
    this.feedId = feedId;
  }

  async generate(
    ctx: Context,
    userId: string | undefined,
    pageSize: number,
    offset: number,
  ): Promise<FeedResponse> {
    const config = await this.config.generate(ctx, userId, pageSize, offset);
    return this.client.fetchFeed(ctx, this.feedId ?? userId, config);
  }
}

export const snotraClient = new SnotraClient();
export const feedClient = new FeedClient();
export const cachedFeedClient = new CachedFeedClient(feedClient, ioRedisPool);

const opts = {
  includeBlockedTags: true,
  includeAllowedTags: true,
  includeBlockedSources: true,
  includeSourceMemberships: true,
};

export const feedGenerators: Record<FeedVersion, FeedGenerator> = Object.freeze(
  {
    '15': new FeedGenerator(
      cachedFeedClient,
      new FeedUserStateConfigGenerator(snotraClient, {
        personalised: new FeedPreferencesConfigGenerator(
          { feed_config_name: FeedConfigName.Vector },
          opts,
        ),
        non_personalised: new FeedPreferencesConfigGenerator(
          { feed_config_name: FeedConfigName.Personalise },
          opts,
        ),
      }),
    ),
    '17': new FeedGenerator(
      cachedFeedClient,
      new FeedUserStateConfigGenerator(snotraClient, {
        personalised: new FeedPreferencesConfigGenerator(
          { feed_config_name: FeedConfigName.VectorM3 },
          opts,
        ),
        non_personalised: new FeedPreferencesConfigGenerator(
          { feed_config_name: FeedConfigName.PersonaliseM3 },
          opts,
        ),
      }),
    ),
    '19': new FeedGenerator(
      cachedFeedClient,
      new FeedUserStateConfigGenerator(snotraClient, {
        personalised: new FeedPreferencesConfigGenerator(
          { feed_config_name: FeedConfigName.VectorE1 },
          opts,
        ),
        non_personalised: new FeedPreferencesConfigGenerator(
          { feed_config_name: FeedConfigName.PersonaliseM3 },
          opts,
        ),
      }),
    ),
    popular: new FeedGenerator(
      cachedFeedClient,
      new SimpleFeedConfigGenerator({
        providers: {
          fresh: {
            enable: true,
            remove_engaged_posts: true,
            page_size_fraction: 0.1,
          },
          engaged: {
            enable: true,
            remove_engaged_posts: true,
            page_size_fraction: 1,
            fallback_provider: 'fresh',
          },
        },
      }),
      'popular',
    ),
    onboarding: new FeedGenerator(
      feedClient,
      new FeedPreferencesConfigGenerator(
        {
          feed_config_name: FeedConfigName.Onboarding,
          total_pages: 1,
        },
        opts,
      ),
      'onboarding',
    ),
  },
);

export const versionToFeedGenerator = (version: number): FeedGenerator => {
  return feedGenerators[version.toString()] ?? feedGenerators['15'];
};
