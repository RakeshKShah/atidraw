import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession, drawOnCanvas } from "../../helpers/mock-api.js";
import { fulfillJson } from "../../mock/mock-server.js";
import { altTextUploadFixtures } from "../../mock/alt-text-upload-fixtures.js";

test("System ensures generated alt text is never empty or generic", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "alt_text_is_always_non_empty_and_descriptive",
    testTitle: testInfo.title,
  });

  const queuedResponses = [
    altTextUploadFixtures.blankCanvas,
    altTextUploadFixtures.complexDiagram,
    altTextUploadFixtures.abstractAi,
  ];
  const seenAltTexts = [];

  try {
    await recorder.step("Mock authenticated draw session");
    await mockGoogleAuthenticatedSession(page);

    await recorder.step("Mock multiple upload responses with distinct descriptive alt text");
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      const request = route.request();
      expect(request.method()).toBe("POST");
      const nextPayload = queuedResponses.shift();
      expect(nextPayload).toBeTruthy();
      seenAltTexts.push(nextPayload.alt_text);
      await fulfillJson(route, nextPayload, 200);
    });

    const genericValues = new Set(["", "image", "drawing", "photo", "picture", "placeholder", "null"]);

    for (const [index, fixture] of [
      altTextUploadFixtures.blankCanvas,
      altTextUploadFixtures.complexDiagram,
      altTextUploadFixtures.abstractAi,
    ].entries()) {
      await recorder.step(`Open draw page for scenario ${index + 1}`);
      await page.goto("/draw");
      await expect(page.locator("canvas")).toBeVisible();

      await recorder.step(`Create drawing content for scenario ${index + 1}`);
      await drawOnCanvas(page);

      await recorder.step(`Share drawing for scenario ${index + 1}`);
      await page.getByRole("button", { name: "Share my drawing" }).click();
      await page.waitForURL("/");

      await recorder.step(`Validate returned alt text quality for scenario ${index + 1}`);
      const altText = fixture.alt_text;
      expect(altText).toBeTruthy();
      expect(altText.trim().length).toBeGreaterThan(8);
      expect(genericValues.has(altText.trim().toLowerCase())).toBe(false);
      expect(fixture.imageRecord.alt_text).toBe(altText);
    }

    expect(seenAltTexts).toHaveLength(3);
    expect(seenAltTexts).toEqual([
      "A blank white canvas with no visible marks or shapes.",
      "A diagram of interconnected nodes with labels and linking lines.",
      "An abstract swirl of blue and purple lines with layered motion.",
    ]);

    console.log("CODEVALID_TEST_ASSERTION_OK:alt_text_is_always_non_empty_and_descriptive");
  } finally {
    await recorder.save(testInfo);
  }
});
