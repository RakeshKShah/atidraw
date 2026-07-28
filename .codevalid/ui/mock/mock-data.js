export const drawingFixtures = {
  google: {
    pathname: "drawings/google-drawing-1.jpg",
    uploadedAt: "2026-07-28T00:00:00.000Z",
    customMetadata: {
      description: "Google drawing",
      userProvider: "google",
      userId: "google-user-1",
      userName: "Google User",
      userAvatar: "https://example.com/google-user.png",
      userUrl: "https://google.example/user/google-user-1",
      url: "https://cdn.example.com/drawings/google-drawing-1.jpg",
      aiImage: "ai/google-drawing-1-ai.jpg",
      aiImageUrl: "https://cdn.example.com/ai/google-drawing-1-ai.jpg",
    },
  },
  github: {
    pathname: "drawings/github-drawing-1.jpg",
    uploadedAt: "2026-07-28T00:00:00.000Z",
    customMetadata: {
      description: "GitHub drawing",
      userProvider: "github",
      userId: "github-user-1",
      userName: "GitHub User",
      userAvatar: "https://example.com/github-user.png",
      userUrl: "https://github.com/github-user-1",
      url: "https://cdn.example.com/drawings/github-drawing-1.jpg",
      aiImage: "ai/github-drawing-1-ai.jpg",
      aiImageUrl: "https://cdn.example.com/ai/github-drawing-1-ai.jpg",
    },
  },
  anonymous: {
    pathname: "drawings/anonymous-drawing-1.jpg",
    uploadedAt: "2026-07-28T00:00:00.000Z",
    customMetadata: {
      description: "Anonymous drawing",
      userProvider: "",
      userId: "",
      userName: "Anonymous User",
      userAvatar: "",
      userUrl: "",
      url: "https://cdn.example.com/drawings/anonymous-drawing-1.jpg",
      aiImage: "ai/anonymous-drawing-1-ai.jpg",
      aiImageUrl: "https://cdn.example.com/ai/anonymous-drawing-1-ai.jpg",
    },
  },
  uploadedGoogle: {
    pathname: "drawings/google-new-drawing.jpg",
    uploadedAt: "2026-07-28T00:05:00.000Z",
    customMetadata: {
      description: "New Google drawing",
      userProvider: "google",
      userId: "google-user-1",
      userName: "Google User",
      userAvatar: "https://example.com/google-user.png",
      userUrl: "https://google.example/user/google-user-1",
      url: "https://cdn.example.com/drawings/google-new-drawing.jpg",
      aiImage: "ai/google-new-drawing-ai.jpg",
      aiImageUrl: "https://cdn.example.com/ai/google-new-drawing-ai.jpg",
    },
  },
  originalOnly: {
    pathname: "drawings/original-only-123.png",
    uploadedAt: "2026-07-28T01:00:00.000Z",
    customMetadata: {
      description: "Original-only drawing",
      userProvider: "user",
      userId: "123",
      userName: "John",
      userAvatar: "https://example.com/john.png",
      userUrl: "https://example.com/users/123",
      url: "https://cdn.example.com/drawings/original-only-123.png",
    },
  },
  aiOnly: {
    pathname: "drawings/ai-only-123.png",
    uploadedAt: "2026-07-28T01:05:00.000Z",
    customMetadata: {
      description: "AI-only artwork",
      userId: "123",
      userName: "Jane",
      url: "https://cdn.example.com/drawings/ai-only-123.png",
      aiImage: "drawings/ai-123.png",
      aiImageUrl: "https://s3.example.com/drawings/ai-123.png",
    },
  },
  combined: {
    pathname: "drawings/combined-456.png",
    uploadedAt: "2026-07-28T01:10:00.000Z",
    customMetadata: {
      description: "Combined drawing with AI variant",
      userProvider: "user",
      userId: "123",
      userName: "Alex",
      userAvatar: "https://example.com/alex.png",
      userUrl: "https://example.com/users/alex",
      url: "https://cdn.example.com/drawings/combined-456.png",
      aiImage: "drawings/ai-456.png",
      aiImageUrl: "https://s3.example.com/drawings/ai-456.png",
    },
  },
  malformedMetadata: {
    pathname: "drawings/malformed-metadata.png",
    uploadedAt: "2026-07-28T01:15:00.000Z",
    customMetadata: {
      url: "https://cdn.example.com/drawings/malformed-metadata.png",
    },
  },
  syncedLocalDrawing: {
    pathname: "drawings/synced-local-drawing.png",
    uploadedAt: "2026-07-28T01:20:00.000Z",
    customMetadata: {
      description: "Synced local drawing",
      userProvider: "local",
      userId: "local-user-1",
      userName: "Local Artist",
      url: "https://cdn.example.com/drawings/synced-local-drawing.png",
      aiImage: null,
    },
  },
  syncedRemoteAi: {
    pathname: "drawings/synced-remote-ai.png",
    uploadedAt: "2026-07-28T01:25:00.000Z",
    customMetadata: {
      description: "Synced remote AI artwork",
      userProvider: "remote",
      userId: "remote-user-1",
      userName: "Remote Artist",
      url: "https://cdn.example.com/drawings/synced-remote-ai.png",
      aiImage: "drawings/synced-remote-ai-overlay.png",
      aiImageUrl: "https://cdn.example.com/drawings/synced-remote-ai-overlay.png",
    },
  },
};

export function buildDrawingsResponse(blobs = [], overrides = {}) {
  return {
    blobs,
    cursor: null,
    hasMore: false,
    ...overrides,
  };
}

export function buildPaginatedFixture(index) {
  return {
    pathname: `drawings/paginated-${index}.png`,
    uploadedAt: `2026-07-28T02:${String(index).padStart(2, "0")}:00.000Z`,
    customMetadata: {
      description: `Paginated artwork ${index}`,
      userProvider: "user",
      userId: `page-user-${index}`,
      userName: `Page User ${index}`,
      url: `https://cdn.example.com/drawings/paginated-${index}.png`,
    },
  };
}

export const googleDrawingsResponse = buildDrawingsResponse([
  drawingFixtures.google,
]);

export const githubDrawingsResponse = buildDrawingsResponse([
  drawingFixtures.github,
]);

export const anonymousDrawingsResponse = buildDrawingsResponse([
  drawingFixtures.anonymous,
]);

export const googleOnlyIsolationResponse = buildDrawingsResponse([
  drawingFixtures.google,
]);

export const githubOnlyIsolationResponse = buildDrawingsResponse([
  drawingFixtures.github,
]);

export const anonymousOnlyIsolationResponse = buildDrawingsResponse([
  drawingFixtures.anonymous,
]);

export const anonymousPersistedDrawingsResponse = buildDrawingsResponse([
  drawingFixtures.anonymous,
]);

export const emptyDrawingsResponse = buildDrawingsResponse([]);

export const uploadedGoogleDrawing = drawingFixtures.uploadedGoogle;

export const uploadedGoogleDrawingsResponse = buildDrawingsResponse([
  drawingFixtures.uploadedGoogle,
]);

export const originalDrawingOnlyResponse = buildDrawingsResponse([
  drawingFixtures.originalOnly,
]);

export const aiImageOnlyResponse = buildDrawingsResponse([
  drawingFixtures.aiOnly,
]);

export const combinedDrawingAndAiResponse = buildDrawingsResponse([
  drawingFixtures.combined,
]);

export const malformedMetadataResponse = buildDrawingsResponse([
  drawingFixtures.malformedMetadata,
]);

export const syncedStorageSourceOfTruthResponse = buildDrawingsResponse([
  drawingFixtures.syncedLocalDrawing,
  drawingFixtures.syncedRemoteAi,
]);

export const paginatedDrawingsPage1 = buildDrawingsResponse(
  Array.from({ length: 20 }, (_, index) => buildPaginatedFixture(index + 1)),
  {
    cursor: "next_token",
    hasMore: true,
  }
);

export const paginatedDrawingsPage2 = buildDrawingsResponse(
  [buildPaginatedFixture(21), buildPaginatedFixture(22)],
  {
    cursor: null,
    hasMore: false,
  }
);
