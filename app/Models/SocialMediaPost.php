<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;

class SocialMediaPost extends Model
{
    protected $fillable = [
        'user_id', 'campaign_id', 'title', 'caption', 'hashtags',
        'media_type', 'media_path', 'platforms', 'platform_content',
        'scheduled_at', 'published_at', 'status', 'approval_status',
        'posting_mode', 'last_error', 'publishing_results',
        'reminder_sent_at', 'posting_started_at', 'posting_notification_sent_at',
    ];

    protected $casts = [
        'platforms' => 'array',
        'platform_content' => 'array',
        'publishing_results' => 'array',
        'scheduled_at' => 'datetime',
        'published_at' => 'datetime',
        'reminder_sent_at' => 'datetime',
        'posting_started_at' => 'datetime',
        'posting_notification_sent_at' => 'datetime',
    ];

    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function campaign(): BelongsTo { return $this->belongsTo(SocialMediaCampaign::class, 'campaign_id'); }
    public function metrics(): HasMany { return $this->hasMany(SocialMediaPostMetric::class, 'social_media_post_id'); }
    public function metricSnapshots(): HasMany { return $this->hasMany(SocialMediaMetricSnapshot::class, 'social_media_post_id'); }

    public function attachedLink(): ?string
    {
        $url = trim((string) data_get($this->platform_content, 'link_url', ''));
        return $url !== '' ? $url : null;
    }

    public function publicMediaUrl(): ?string
    {
        $path = trim((string) $this->media_path);
        if ($path === '') return null;
        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) return $path;
        return Storage::disk('public')->url($path);
    }

    public function shareText(): string
    {
        return collect([
            trim((string) $this->caption),
            trim((string) $this->hashtags),
            $this->attachedLink(),
        ])->filter()->implode("\n\n");
    }
}
