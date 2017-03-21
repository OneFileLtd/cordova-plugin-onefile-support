using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Windows.ApplicationModel;
using Windows.Foundation;
using Windows.Storage;

namespace ZipUtil
{
    public sealed class Zipper
    {
        public IAsyncOperation<IStorageFile> ZipFiles(string zipFileName, IList<IStorageFile> files)
        {
            return ZipFilesAsync(zipFileName, files).AsAsyncOperation();
        }

        public IAsyncOperation<StorageFile> ZipFilesFromPath(IEnumerable<string> files)
        {
            return ZipFilesAsync(files).AsAsyncOperation();
        }

        private async Task<IStorageFile> ZipFilesAsync(string zipFileName, IList<IStorageFile> files)
        {
            var storageFolder = ApplicationData.Current.TemporaryFolder;
            var zipFile = await storageFolder.CreateFileAsync(zipFileName + ".zip", CreationCollisionOption.ReplaceExisting);
            var replaceLength = (ApplicationData.Current.LocalFolder.Name + @"\").Length;
            using (Stream zipToOpen = (await zipFile.OpenAsync(FileAccessMode.ReadWrite)).AsStream())
            using (ZipArchive archive = new ZipArchive(zipToOpen, ZipArchiveMode.Create))
            {
                for (int i = 0; i < files.Count; i++)
                {
                    var fullName = Package.Current.Id.FullName;
                    var file = files[i];
                    var startIndex = file.Path.IndexOf(ApplicationData.Current.LocalFolder.Name + @"\");
                    ZipArchiveEntry readmeEntry = archive.CreateEntry(file.Path.Substring(startIndex + replaceLength, file.Path.Length - (startIndex + replaceLength)).Replace(@"\", "/"));
                    using (StreamWriter writer = new StreamWriter(readmeEntry.Open()))
                    using (var zipfileStream = await file.OpenStreamForReadAsync())
                    {
                        zipfileStream.CopyTo(writer.BaseStream);
                    }
                }
            }
            return zipFile;
        }

        private async Task<StorageFile> ZipFilesAsync(IEnumerable<string> files)
        {
            try
            {

                List<StorageFile> sFiles = new List<StorageFile>();
                for (int i = 0; i < files.Count(); i++)
                {
                    sFiles.Add(await ApplicationData.Current.LocalFolder.GetFileAsync(files.ElementAt(i)));
                }

                var storageFolder = ApplicationData.Current.LocalFolder;
                var zipFile = await storageFolder.CreateFileAsync("supportUpload.zip", CreationCollisionOption.ReplaceExisting);

                using (Stream zipToOpen = (await zipFile.OpenAsync(FileAccessMode.ReadWrite)).AsStream())
                using (ZipArchive archive = new ZipArchive(zipToOpen, ZipArchiveMode.Create))
                {
                    for (int i = 0; i < sFiles.Count; i++)
                    {
                        ZipArchiveEntry readmeEntry = archive.CreateEntry(sFiles[i].Name);
                        using (StreamWriter writer = new StreamWriter(readmeEntry.Open()))
                        using (var zipfileStream = await sFiles[i].OpenStreamForReadAsync())
                        {
                            zipfileStream.CopyTo(writer.BaseStream);
                        }
                    }
                }

                return zipFile;
            }
            catch (Exception e)
            {
                Debug.WriteLine(e.StackTrace);
                return null;
            }
        }
    }
}
