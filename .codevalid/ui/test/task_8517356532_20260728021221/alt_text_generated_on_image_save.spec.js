import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession, drawOnCanvas } from "../../helpers/mock-api.js";
import { fulfillJson } from "../../mock/mock-server.js";
import { altTextUploadFixtures } from "../../mock/alt-text-upload-fixtures.js";

test("Alt text is auto-generated upon saving a drawing or AI image", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "alt_text_generated_on_image_save",
    testTitle: testInfo.title,
  });

  const uploadResponses = [];

  try {
    await recorder.step("Mock authenticated draw session");
    await mockGoogleAuthenticatedSession(page);

    await recorder.step("Mock POST /api/upload with generated alt_text payload");
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      const request = route.request();
      expect(request.method()).toBe("POST");
      uploadResponses.push(altTextUploadFixtures.descriptiveLandscape);
      await fulfillJson(route, altTextUploadFixtures.descriptiveLandscape, 200);
    });

    await recorder.step("Open the draw page");
    await page.goto("/draw");

    await recorder.step("Verify draw interface is visible");
    await expect(page.getByText("Create a drawing and share it with the world!")).toBeVisible();
    await expect(page.locator("canvas")).toBeVisible();
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();

    await recorder.step("Create a drawing on the canvas");
    await drawOnCanvas(page);

    await recorder.step("Share the drawing");
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
    await page.getByRole("button", { name: "Share my drawing" }).click();

    await recorder.step("Assert generated alt text is returned and save completes");
    await page.waitForURL("/");
    expect(uploadResponses).toHaveLength(1);
    expect(uploadResponses[0].alt_text).toBeTruthy();
    expect(uploadResponses[0].alt_text.trim().length).toBeGreaterThan(10);
    await expect.poll(() => uploadResponses[0].alt_text.toLowerCase()).not.toContain("image");
    await expect.poll(() => uploadResponses[0].alt_text.toLowerCase()).not.toBe("drawing");
    expect(uploadResponses[0].imageRecord.alt_text).toBe(uploadResponses[0].alt_text);
    expect(uploadResponses[0].imageRecord.id).toBeTruthy();

    console.log("CODEVALID_TEST_ASSERTION_OK:alt_text_generated_on_image_save");
  } finally {
    await recorder.save(testInfo);
  }
});
