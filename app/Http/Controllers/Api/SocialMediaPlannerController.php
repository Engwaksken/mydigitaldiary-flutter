<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SocialMediaPost;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class SocialMediaPlannerController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(
            SocialMediaPost::query()
                ->where('user_id', $request->user()->id)
                ->orderByRaw('scheduled_at IS NULL')
                ->orderBy('scheduled_at')
                ->paginate((int) $request->input('per_page', 20))
        );
    }

    public function store(Request $request)
    {
        $data = $this->validated($request);
        $data = $this->prepareAttachments($request, $data);

        $post = SocialMediaPost::create([
            ...$data,
            'user_id' => $request->user()->id,
            'status' => !empty($data['scheduled_at']) ? 'scheduled' : 'draft',
            'approval_status' => $data['approval_status'] ?? 'approved',
        ]);

        return response()->json(['data' => $post->fresh()], 201);
    }

    public function update(Request $request, SocialMediaPost $socialMediaPost)
    {
        abort_unless($socialMediaPost->user_id === $request->user()->id, 403);

        $data = $this->validated($request);
        $data = $this->prepareAttachments($request, $data, $socialMediaPost);
        $data['status'] = !empty($data['scheduled_at']) ? 'scheduled' : 'draft';

        $socialMediaPost->update($data);

        return response()->json(['data' => $socialMediaPost->fresh()]);
    }

    public function destroy(Request $request, SocialMediaPost $socialMediaPost)
    {
        abort_unless($socialMediaPost->user_id === $request->user()->id, 403);
        $this->deleteStoredMedia($socialMediaPost->media_path);
        $socialMediaPost->delete();

        return response()->json(['ok' => true]);
    }

    public function bulkDestroy(Request $request)
    {
        $data = $request->validate([
            'ids' => ['required', 'array', 'min:1', 'max:100'],
            'ids.*' => ['integer'],
        ]);

        $posts = SocialMediaPost::query()
            ->where('user_id', $request->user()->id)
            ->whereIn('id', $data['ids'])
            ->get();

        foreach ($posts as $post) {
            $this->deleteStoredMedia($post->media_path);
        }

        $deleted = SocialMediaPost::query()
            ->where('user_id', $request->user()->id)
            ->whereIn('id', $data['ids'])
            ->delete();

        return response()->json([
            'ok' => true,
            'deleted' => $deleted,
        ]);
    }

    public function postNow(Request $request, SocialMediaPost $socialMediaPost)
    {
        abort_unless($socialMediaPost->user_id === $request->user()->id, 403);

        if ($socialMediaPost->status !== 'published') {
            $socialMediaPost->forceFill(['status' => 'ready_to_share'])->save();
        }

        return response()->json([
            'data' => [
                'id' => $socialMediaPost->id,
                'title' => $socialMediaPost->title,
                'text' => $socialMediaPost->shareText(),
                'media_url' => $socialMediaPost->publicMediaUrl(),
                'link_url' => $socialMediaPost->attachedLink(),
                'platforms' => $socialMediaPost->platforms ?? [],
                'status' => $socialMediaPost->status,
            ],
        ]);
    }

    public function markPublished(Request $request, SocialMediaPost $socialMediaPost)
    {
        abort_unless($socialMediaPost->user_id === $request->user()->id, 403);

        $socialMediaPost->forceFill([
            'status' => 'published',
            'published_at' => now(),
            'last_error' => null,
        ])->save();

        return response()->json(['data' => $socialMediaPost->fresh()]);
    }

    public function readyToShare(Request $request)
    {
        $posts = SocialMediaPost::query()
            ->where('user_id', $request->user()->id)
            ->where(function ($query) {
                $query->where('status', 'ready_to_share')
                    ->orWhere(function ($due) {
                        $due->where('status', 'scheduled')
                            ->whereNotNull('scheduled_at')
                            ->where('scheduled_at', '<=', now());
                    });
            })
            ->orderBy('scheduled_at')
            ->get();

        return response()->json(['data' => $posts]);
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'campaign_id' => ['nullable', 'integer'],
            'title' => ['required', 'string', 'max:180'],
            'caption' => ['nullable', 'string', 'max:10000'],
            'hashtags' => ['nullable', 'string', 'max:2000'],
            'attachment' => [
                'nullable',
                'file',
                'max:51200',
                'mimetypes:image/jpeg,image/png,image/webp,image/gif,video/mp4,video/quicktime,video/webm',
            ],
            'link_url' => ['nullable', 'url:http,https', 'max:2000'],
            'remove_media' => ['nullable', 'boolean'],
            'platforms' => ['required', 'array', 'min:1'],
            'platforms.*' => [Rule::in([
                'instagram', 'facebook', 'x', 'tiktok', 'linkedin',
                'whatsapp_status', 'whatsapp_channel',
            ])],
            'scheduled_at' => ['nullable', 'date'],
            'approval_status' => ['nullable', Rule::in([
                'draft', 'pending', 'approved', 'rejected',
            ])],
            'posting_mode' => ['nullable', Rule::in(['manual', 'automatic'])],
        ]);
    }

    private function prepareAttachments(
        Request $request,
        array $data,
        ?SocialMediaPost $existing = null
    ): array {
        unset($data['attachment'], $data['remove_media'], $data['link_url']);

        $platformContent = (array) ($existing?->platform_content ?? []);
        $link = trim((string) $request->input('link_url', ''));

        if ($link !== '') {
            $platformContent['link_url'] = $link;
        } else {
            unset($platformContent['link_url']);
        }

        $data['platform_content'] = $platformContent ?: null;
        $data['posting_mode'] = $request->input('posting_mode', 'manual');

        $mediaPath = $existing?->media_path;
        $mediaType = $existing?->media_type ?: 'text';

        if ($request->boolean('remove_media')) {
            $this->deleteStoredMedia($mediaPath);
            $mediaPath = null;
            $mediaType = 'text';
        }

        if ($request->hasFile('attachment')) {
            $this->deleteStoredMedia($mediaPath);

            $file = $request->file('attachment');
            $mediaPath = $file->store(
                'social-media-posts/' . $request->user()->id,
                'public'
            );
            $mediaType = str_starts_with((string) $file->getMimeType(), 'video/')
                ? 'video'
                : 'image';
        }

        $data['media_path'] = $mediaPath;
        $data['media_type'] = $mediaPath ? $mediaType : 'text';

        return $data;
    }

    private function deleteStoredMedia(?string $path): void
    {
        $path = trim((string) $path);

        if ($path === '' ||
            str_starts_with($path, 'http://') ||
            str_starts_with($path, 'https://')) {
            return;
        }

        Storage::disk('public')->delete($path);
    }
}
