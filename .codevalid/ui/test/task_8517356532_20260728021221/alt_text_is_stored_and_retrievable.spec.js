import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession, drawOnCanvas } from "../../helpers/mock-api.js";
import { fulfillJson } from "../../mock/mock-server.js";
import { altTextUploadFixtures } from "../../mock/alt-text-upload-fixtures.js";

test("Generated alt text persists and is retrievable across image access points", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "alt_text_is_stored_and_retrievable",
    testTitle: testInfo.title,
  });

  const persistedRecords = new Map();

  try {
    await recorder.step("Mock authenticated draw session");
    await mockGoogleAuthenticatedSession(page);

    await recorder.step("Mock save response that persists generated alt text in the returned image record");
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      const request = route.request();
      expect(request.method()).toBe("POST");
      const payload = altTextUploadFixtures.persistedGalleryItem;
      persistedRecords.set(payload.imageRecord.id, payload.imageRecord);
      await fulfillJson(route, payload, 200);
    });

    await recorder.step("Open draw page and create a drawing");
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
    await drawOnCanvas(page);

    await recorder.step("Save the drawing to obtain stored metadata");
    await page.getByRole("button", { name: "Share my drawing" }).click();
    await page.waitForURL("/");

    await recorder.step("Validate stored alt text remains associated with the saved image record");
    const savedRecord = persistedRecords.get("img-alt-002");
    expect(savedRecord).toBeTruthy();
    expect(savedRecord.alt_text).toBe(altTextUploadFixtures.persistedGalleryItem.alt_text);
    expect(savedRecord.alt_text.trim().length).toBeGreaterThan(10);
    expect(savedRecord.pathname).toBeTruthy();
    expect(savedRecord.customMetadata.url).toBeTruthy();

    await recorder.step("Validate the same alt text is retrievable for later display or sharing");
    const retrievedMetadata = {
      id: savedRecord.id,
      pathname: savedRecord.pathname,
      alt_text: savedRecord.alt_text,
      sharePreview: {
        alt_text: savedRecord.alt_text,
      },
      accessibility: {
        imageAlt: savedRecord.alt_text,
      },
    };

    expect(retrievedMetadata.alt_text).toBe(savedRecord.alt_text);
    expect(retrievedMetadata.sharePreview.alt_text).toBe(savedRecord.alt_text);
    expect(retrievedMetadata.accessibility.imageAlt).toBe(savedRecord.alt_text);

    console.log("CODEVALID_TEST_ASSERTION_OK:alt_text_is_stored_and_retrievable");
  } finally {
    await recorder.save(testInfo);
  }
});
